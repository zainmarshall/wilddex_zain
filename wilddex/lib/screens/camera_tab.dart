import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/shutter_button.dart';
import 'prediction_result_screen.dart';
import '../utils/photo_saver.dart';
import '../utils/settings_provider.dart';

const double kCameraMinZoom = 1.0 ; 
const double kCameraMaxZoom = 189.0; //physical max before error is 189
const String kSampleImageAsset = 'assets/data/lion.png';

Future<Map<String, dynamic>> uploadImageAndGetPrediction(
  File imageFile, {
  required String apiBaseUrl,
  required bool useCrops,
}) async {
  final uri = Uri.parse('$apiBaseUrl/predict').replace(
    queryParameters: {'use_crops': useCrops ? 'true' : 'false'},
  );
  final request = http.MultipartRequest('POST', uri);
  request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

  final response = await request.send();
  if (response.statusCode == 200) {
    final respStr = await response.stream.bytesToString();
    return jsonDecode(respStr);
  } else {
    throw Exception('Failed to get prediction: ${response.statusCode}');
  }
}

Future<void> runPredictionFlow(BuildContext context, File imageFile) async {
  final settings = Provider.of<SettingsProvider>(context, listen: false);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PredictionResultScreen(
      imageFile: imageFile,
      isLoading: true,
    ),
  ));
  try {
    final prediction = await uploadImageAndGetPrediction(
      imageFile,
      apiBaseUrl: settings.apiBaseUrl,
      useCrops: settings.useCropModel,
    );
    final binomialName = prediction['scientific_name'] ?? 'unknown';
    await savePhotoToGallery(imageFile, binomialName: binomialName);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PredictionResultScreen(
        imageFile: imageFile,
        predictionResult: prediction,
        isLoading: false,
      ),
    ));
  } catch (e) {
    debugPrint('Prediction error: $e');
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PredictionResultScreen(
        imageFile: imageFile,
        predictionResult: {'error': e.toString()},
        isLoading: false,
      ),
    ));
  }
}

class CameraTab extends StatefulWidget {
  final CameraDescription camera;
  const CameraTab({super.key, required this.camera});

  @override
  State<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends State<CameraTab> with SingleTickerProviderStateMixin {
  bool _showBlackFlick = false;
  // ...existing code...
  CameraController? _controller;
  bool _isInit = false;
  bool _hasError = false;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0; // Used for pinch-to-zoom gesture

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }


  Future<void> _setupCamera() async {
    try {
      final controller = CameraController(
        widget.camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      // Set initial zoom
      await controller.setZoomLevel(_currentZoom);
      setState(() {
        _controller = controller;
        _isInit = true;
      });
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _takePicture() async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        setState(() => _showBlackFlick = true);
        await Future.delayed(const Duration(milliseconds: 80));
        setState(() => _showBlackFlick = false);
        final image = await _controller!.takePicture();
        // Show loading screen while waiting for prediction
        if (!mounted) return;
        await runPredictionFlow(context, File(image.path));
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SampleCameraTab(
        errorMessage: 'Camera unavailable. Using sample image.',
      );
    }

    if (!_isInit || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onScaleStart: (details) {
              _baseZoom = _currentZoom;
            },
            onScaleUpdate: (details) async {
              if (_controller != null && _controller!.value.isInitialized) {
                double newZoom = (_baseZoom * details.scale).clamp(kCameraMinZoom, kCameraMaxZoom);
                setState(() {
                  _currentZoom = newZoom;
                });
                await _controller!.setZoomLevel(_currentZoom);
              }
            },
            child: CameraPreview(_controller!),
          ),
        ),
        // Black flick overlay
        if (_showBlackFlick)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showBlackFlick ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 80),
              child: Container(color: Colors.black),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32.0),
            child: ShutterButton(
              onTap: () {
                if (_controller != null && _controller!.value.isInitialized) {
                  _takePicture();
                } else {
                  debugPrint('Camera not initialized, ignoring shutter press');
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class SampleCameraTab extends StatefulWidget {
  final String? errorMessage;
  const SampleCameraTab({super.key, this.errorMessage});

  @override
  State<SampleCameraTab> createState() => _SampleCameraTabState();
}

class _SampleCameraTabState extends State<SampleCameraTab> {
  bool _isLoading = false;

  Future<File> _loadSampleImage() async {
    final bytes = await rootBundle.load(kSampleImageAsset);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sample_lion.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }

  Future<void> _runSample() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final file = await _loadSampleImage();
      if (!mounted) return;
      await runPredictionFlow(context, file);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            kSampleImageAsset,
            fit: BoxFit.cover,
          ),
        ),
        if (widget.errorMessage != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black.withOpacity(0.6),
                child: Text(
                  widget.errorMessage!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32.0),
            child: ShutterButton(
              onTap: _isLoading ? () {} : () => _runSample(),
            ),
          ),
        ),
      ],
    );
  }
}
         

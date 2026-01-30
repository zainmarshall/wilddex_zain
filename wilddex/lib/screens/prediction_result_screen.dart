import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/app_data.dart';
import '../models/species.dart';
import '../utils/user_data_provider.dart';
import '../theme/colors.dart';
import 'animal_detail_screen.dart';

class PredictionResultScreen extends StatelessWidget {
  final File imageFile;
  final Map<String, dynamic>? predictionResult;
  final bool isLoading;

  const PredictionResultScreen({
    Key? key,
    required this.imageFile,
    this.predictionResult,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String genus = predictionResult?['genus'] ?? '';
    String species = predictionResult?['species'] ?? '';
    // MAP Weird subspecies things to the correct thing   
    if (genus.toLowerCase() == 'canis' && species.toLowerCase() == 'familiaris') {
      species = 'lupus familiaris';
    }
    final boundingBox = (predictionResult?['bounding_box'] as List?)
        ?.cast<double>();

    final appData = Provider.of<AppData>(context, listen: false);
    final lookupKey = '${genus.toLowerCase()}|${species.toLowerCase()}';
    final found = appData.speciesByGenusSpecies[lookupKey];
    final errorMessage = predictionResult?['error'] as String?;

    if (found != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = Provider.of<UserDataProvider>(
          context,
          listen: false,
        );
        if (!provider.isSpeciesDiscovered(found.id)) {
          provider.discoverSpecies(found.id);
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New species discovered!')),
          );
        }
        provider.addSightingIfNew(found.id, imageFile.path);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: const Text('Prediction Result'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                    const SizedBox(height: 24),
                    if (isLoading) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 48.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Identifying species...',
                        style: TextStyle(color: AppColors.text),
                      ),
                    ] else if (predictionResult == null) ...[
                      _buildMessageState(
                        context,
                        'No prediction available. Try again.',
                        Icons.help_outline,
                      ),
                    ] else if (errorMessage != null) ...[
                      _buildMessageState(
                        context,
                        errorMessage,
                        Icons.error_outline,
                      ),
                    ] else if (found == null) ...[
                      _buildMessageState(
                        context,
                        'No match in the Dex for $genus $species.',
                        Icons.search_off,
                      ),
                    ] else ...[
                      // Species name and new badge
                      Consumer<UserDataProvider>(
                        builder: (context, provider, _) {
                          final isDiscovered = provider.isSpeciesDiscovered(found?.id ?? '');
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    found?.name ?? '',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (!isDiscovered)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Text(
                                        'NEW',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              // Scientific name under common name
                              if (found?.classification != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '${found?.classification?.genus ?? ''} ${found?.classification?.species ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                     
                      // View Species button
                      ElevatedButton(
                        onPressed: () {
                          if (found != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    AnimalDetailScreen(species: found!),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('VIEW SPECIES'),
                      ),
                      const SizedBox(height: 32),


                      // Species database photo (second row)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.network(
                              found.apiImageUrl,
                              width: 320,
                              height: 320,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  width: 320,
                                  height: 320,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.accent,
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              (loadingProgress.expectedTotalBytes ?? 1)
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 320,
                                  height: 320,
                                  color: AppColors.background,
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                      color: AppColors.text,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                       Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.file(
                                  imageFile,
                                  width: 320,
                                  height: 320,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (boundingBox != null && boundingBox.length == 4)
                                Positioned(
                                  left: boundingBox[0] * 320,
                                  top: boundingBox[1] * 320,
                                  width: boundingBox[2] * 320,
                                  height: boundingBox[3] * 320,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.red,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageState(
    BuildContext context,
    String message,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.amber),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: AppColors.text),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('BACK TO CAMERA'),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<File> savePhotoToGallery(File imageFile, {String? binomialName}) async {
  final dir = await getApplicationDocumentsDirectory();
  final photosDir = Directory('${dir.path}/photos');
  if (!await photosDir.exists()) {
    await photosDir.create(recursive: true);
  }
  final String safeName = binomialName != null ? binomialName.toLowerCase().replaceAll(' ', '_') : 'unknown';
  final String fileName = safeName + '_' + DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
  final File newFile = await imageFile.copy('${photosDir.path}/$fileName');
  return newFile;
}

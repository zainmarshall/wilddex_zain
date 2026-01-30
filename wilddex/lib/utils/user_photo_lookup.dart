import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<File?> getUserPhotoForSpecies(String binomialName) async {
  final dir = await getApplicationDocumentsDirectory();
  final photosDir = Directory('${dir.path}/photos');
  if (!await photosDir.exists()) return null;
  final safeName = binomialName.toLowerCase().replaceAll(' ', '_');
  final files = photosDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.contains(safeName) && f.path.endsWith('.jpg'))
      .toList();
  if (files.isNotEmpty) {
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.first;
  }
  return null;
}

import 'species.dart';

class Family {
  final String name;
  final String scientificName;
  final String description;
  final List<Species> species;
  final String? image;

  Family({
    required this.name,
    required this.scientificName,
    required this.description,
    required this.species,
    this.image,
  });

  bool get hasDiscoveredSpecies => species.any((s) => s.isDiscovered);
  int get discoveredSpeciesCount => species.where((s) => s.isDiscovered).length;
  double get discoveryProgress => species.isEmpty ? 0 : discoveredSpeciesCount / species.length;

  factory Family.fromSpeciesList(List<Species> speciesList) {
    if (speciesList.isEmpty) {
      throw ArgumentError('Cannot create a family from an empty species list');
    }

    final firstSpecies = speciesList.first;
    final familyName = firstSpecies.classification?.familyName ?? 'Unknown Family';
    final scientificName = firstSpecies.classification?.family ?? 'Unknown';

    return Family(
      name: familyName,
      scientificName: scientificName,
      description: 'A family of ${speciesList.length} species',
      species: speciesList,
      image: speciesList.firstWhere((s) => s.image != null, orElse: () => speciesList.first).image,
    );
  }
} 
import '../data/app_data.dart';
import '../models/species.dart';

class ParkGuide {
  final String id;
  final String name;
  final String description;
  final List<Species> species;

  ParkGuide({
    required this.id,
    required this.name,
    required this.description,
    required this.species,
  });
}

List<ParkGuide> buildParkGuides(
  AppData appData, {
  Set<String>? allowedIds,
}) {
  return appData.parksList.map((park) {
    final species = park.speciesIds
        .where((id) => allowedIds == null || allowedIds.contains(id))
        .map((id) => appData.speciesById[id])
        .whereType<Species>()
        .toList(growable: false);
    return ParkGuide(
      id: park.id,
      name: park.name,
      description: park.description,
      species: species,
    );
  }).toList(growable: false);
}

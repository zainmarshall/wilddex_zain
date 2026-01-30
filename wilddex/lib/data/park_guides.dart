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

List<ParkGuide> buildParkGuides(List<Species> allSpecies) {
  List<Species> resolveSpecies(List<String> names) {
    final lookup = <String, Species>{};
    for (final species in allSpecies) {
      final common = species.name.toLowerCase();
      final scientific = species.scientificName.toLowerCase();
      lookup[common] = species;
      lookup[scientific] = species;
    }

    final results = <Species>[];
    final seenIds = <String>{};
    for (final name in names) {
      final key = name.toLowerCase().trim();
      final match = lookup[key];
      if (match != null && !seenIds.contains(match.id)) {
        seenIds.add(match.id);
        results.add(match);
      }
    }
    return results;
  }

  final yellowstoneSpecies = resolveSpecies([
    'Badger',
    'American badger',
    'Black bear',
    'American black bear',
    'Grizzly bear',
    'Bobcat',
    'Canada lynx',
    'Cougar',
    'Coyote',
    'Wolf',
    'Gray wolf',
    'Long-tailed weasel',
    'American ermine',
    'Marten',
    'American marten',
    'Red fox',
    'River otter',
    'North American river otter',
    'Short-tailed weasel',
    'American mink',
    'Wolverine',
    'American bison',
    'Bighorn sheep',
    'Elk',
    'Moose',
    'Mountain goat',
    'Mule deer',
    'Pronghorn',
    'White-tailed deer',
    'Beaver',
    'Golden-mantled ground squirrel',
    'Least chipmunk',
    'Montane vole',
    'Pocket gopher',
    'Red squirrel',
    'Uinta ground squirrel',
    'Yellow-bellied marmot',
    'Pika',
    'Snowshoe hare',
    'White-tailed jackrabbit',
  ]);

  final yosemiteSpecies = resolveSpecies([
    'Taricha sierrae',
    'Batrachoseps gregarius',
    'Batrachoseps diabolicus',
    'Ensatina eschscholtzii platensis',
    'Ensatina eschscholtzii xanthoptica',
    'Aneides lugubris',
    'Hydromantes platycephalus',
    'Anaxyrus boreas halophilus',
    'Anaxyrus canorus',
    'Pseudacris regilla',
    'Rana draytonii',
    'Rana boylii',
    'Rana sierrae',
    'Lithobates catesbeiana',
  ]);

  final greatFallsSpecies = resolveSpecies([
    'Canada goose',
    'Mallard',
    'American black duck',
    'Ring-necked duck',
    'Bufflehead',
    'Common merganser',
    'Ring-billed gull',
    'Great blue heron',
    'Black vulture',
    'Turkey vulture',
    'Cooper\'s hawk',
    'Bald eagle',
    'Red-shouldered hawk',
    'Yellow-bellied sapsucker',
    'Red-bellied woodpecker',
    'Hairy woodpecker',
    'Pileated woodpecker',
    'Northern flicker',
    'Blue jay',
    'American crow',
    'Fish crow',
    'Carolina chickadee',
    'Tufted titmouse',
    'Ruby-crowned kinglet',
    'Golden-crowned kinglet',
    'White-breasted nuthatch',
    'Winter wren',
    'Carolina wren',
    'Eastern bluebird',
    'Red-flanked bluetail',
    'Cedar waxwing',
    'American goldfinch',
    'Dark-eyed junco',
    'White-throated sparrow',
    'Song sparrow',
    'Eastern towhee',
    'Yellow-rumped warbler',
    'Northern cardinal',
  ]);

  return [
    ParkGuide(
      id: 'yellowstone',
      name: 'Yellowstone National Park',
      description: 'Mammal field list from the Yellowstone NPS species page.',
      species: yellowstoneSpecies,
    ),
    ParkGuide(
      id: 'great_falls',
      name: 'Great Falls Park',
      description: 'Bird count highlights from the Great Falls Park NPS page.',
      species: greatFallsSpecies,
    ),
    ParkGuide(
      id: 'yosemite',
      name: 'Yosemite National Park',
      description: 'Amphibian species list from Yosemite NPS resources.',
      species: yosemiteSpecies,
    ),
  ];
}

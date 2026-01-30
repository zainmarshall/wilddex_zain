class Park {
  final String id;
  final String name;
  final String code;
  final String state;
  final String description;
  final List<String> speciesIds;

  const Park({
    required this.id,
    required this.name,
    required this.code,
    required this.state,
    required this.description,
    required this.speciesIds,
  });

  factory Park.fromJson(Map<String, dynamic> json) {
    final speciesRaw = json['speciesIds'] ?? json['species_ids'] ?? [];
    final speciesIds = speciesRaw is List
        ? speciesRaw.map((e) => e.toString()).toList(growable: false)
        : <String>[];
    return Park(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      speciesIds: speciesIds,
    );
  }
}

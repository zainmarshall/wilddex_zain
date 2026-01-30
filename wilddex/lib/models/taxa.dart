class Taxa {
  final String name;
  final String commonName;
  final String rank;
  final String description;

  Taxa({
    required this.name,
    required this.commonName,
    required this.rank,
    required this.description,
  });

  factory Taxa.fromJson(Map<String, dynamic> json) {
  return Taxa(
    name: json['name'] as String? ?? '',
    commonName: json['common_name'] as String? ?? '',
    rank: json['rank'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}
}

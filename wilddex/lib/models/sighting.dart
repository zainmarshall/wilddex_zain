class Sighting {
  final String imagePath;
  final DateTime timestamp;

  Sighting({
    required this.imagePath,
    required this.timestamp,
  });

  factory Sighting.fromJson(Map<String, dynamic> json) {
    return Sighting(
      imagePath: json['imagePath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
    };
  }
} 
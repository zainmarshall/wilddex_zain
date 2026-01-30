class BadgeCriteria {
  final String type;
  final int? count;
  final int? startHour;
  final int? endHour;

  BadgeCriteria({
    required this.type,
    this.count,
    this.startHour,
    this.endHour,
  });

  factory BadgeCriteria.fromJson(Map<String, dynamic> json) {
    return BadgeCriteria(
      type: json['type'] as String? ?? '',
      count: json['count'] as int?,
      startHour: json['startHour'] as int?,
      endHour: json['endHour'] as int?,
    );
  }
}

class BadgeDefinition {
  final String id;
  final String name;
  final String tier;
  final String description;
  final BadgeCriteria criteria;

  BadgeDefinition({
    required this.id,
    required this.name,
    required this.tier,
    required this.description,
    required this.criteria,
  });

  factory BadgeDefinition.fromJson(Map<String, dynamic> json) {
    return BadgeDefinition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tier: json['tier'] as String? ?? 'common',
      description: json['description'] as String? ?? '',
      criteria: BadgeCriteria.fromJson(
        (json['criteria'] as Map<String, dynamic>? ?? const {}),
      ),
    );
  }
}

class BadgeStatus {
  final BadgeDefinition definition;
  final int current;
  final int target;
  final bool isEarned;
  final DateTime? earnedAt;

  BadgeStatus({
    required this.definition,
    required this.current,
    required this.target,
    required this.isEarned,
    this.earnedAt,
  });

  double get progress {
    if (target <= 0) return isEarned ? 1.0 : 0.0;
    return (current / target).clamp(0.0, 1.0);
  }

  bool get isComplete => target <= 0 ? isEarned : current >= target;
}

class BadgeSummary {
  final List<BadgeStatus> badges;
  final int totalPoints;
  final String levelName;

  BadgeSummary({
    required this.badges,
    required this.totalPoints,
    required this.levelName,
  });
}

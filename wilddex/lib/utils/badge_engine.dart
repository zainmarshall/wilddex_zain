import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/app_data.dart';
import '../data/park_guides.dart';
import '../models/badge.dart';
import '../models/species.dart';
import '../utils/user_data_provider.dart';

class BadgeEngine {
  static Future<List<BadgeDefinition>>? _definitionsFuture;
  static bool _isSyncing = false;

  static Future<List<BadgeDefinition>> loadDefinitions() {
    _definitionsFuture ??= _loadDefinitionsInternal();
    return _definitionsFuture!;
  }

  static Future<List<BadgeDefinition>> _loadDefinitionsInternal() async {
    final raw = await rootBundle.loadString('assets/data/badges.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => BadgeDefinition.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Future<void> syncAwards(BuildContext context) async {
    if (_isSyncing) return;
    final userData = Provider.of<UserDataProvider>(context, listen: false);
    if (!userData.isInitialized) return;
    if (!userData.needsBadgeSync) return;
    _isSyncing = true;
    try {
      final appData = Provider.of<AppData>(context, listen: false);
      final defs = await loadDefinitions();
      final summary = evaluate(defs, appData, userData);
      final newlyEarned = summary.badges
          .where((b) => b.isComplete && !b.isEarned)
          .map((b) => b.definition.id)
          .toList();
      if (newlyEarned.isNotEmpty) {
        await userData.awardBadges(newlyEarned);
      }
      userData.markBadgeSyncComplete();
    } finally {
      _isSyncing = false;
    }
  }

  static BadgeSummary evaluate(
    List<BadgeDefinition> definitions,
    AppData appData,
    UserDataProvider userData,
  ) {
    final discoveredIds = userData.discoveredSpeciesIds;
    final discoveredSpecies = discoveredIds
        .map((id) => appData.speciesById[id])
        .whereType<Species>()
        .toList(growable: false);

    final families = _distinctValues(discoveredSpecies, (s) => s.classification?.family);
    final orders = _distinctValues(discoveredSpecies, (s) => s.classification?.order);
    final classes = _distinctValues(discoveredSpecies, (s) => s.classification?.class_);

    final parkGuides = buildParkGuides(appData.speciesList);
    final parkProgress = _parkProgress(parkGuides, discoveredIds);
    final timeOfDayCount = _discoveriesByTimeOfDay(userData);
    final streakDays = userData.streakDays ?? 0;

    final statuses = <BadgeStatus>[];
    for (final def in definitions) {
      final criteria = def.criteria;
      int current = 0;
      int target = criteria.count ?? 0;

      switch (criteria.type) {
        case 'discover_count':
          current = discoveredIds.length;
          break;
        case 'discover_distinct_family':
          current = families.length;
          break;
        case 'discover_distinct_order':
          current = orders.length;
          break;
        case 'discover_distinct_class':
          current = classes.length;
          break;
        case 'discover_in_park':
          current = parkProgress.bestCount;
          break;
        case 'complete_any_park':
          current = parkProgress.anyComplete ? 1 : 0;
          target = 1;
          break;
        case 'discover_time_of_day':
          current = _countTimeOfDay(
            timeOfDayCount,
            criteria.startHour ?? 0,
            criteria.endHour ?? 24,
          );
          break;
        case 'streak_days':
          current = streakDays;
          break;
        default:
          current = 0;
      }

      final earnedAt = userData.earnedBadges[def.id];
      final isEarned = earnedAt != null;
      statuses.add(
        BadgeStatus(
          definition: def,
          current: current,
          target: target,
          isEarned: isEarned,
          earnedAt: earnedAt,
        ),
      );
    }

    final totalPoints = statuses
        .where((b) => b.isEarned || b.isComplete)
        .fold<int>(0, (sum, b) => sum + pointsForTier(b.definition.tier));
    final levelName = levelForPoints(totalPoints);

    return BadgeSummary(
      badges: statuses,
      totalPoints: totalPoints,
      levelName: levelName,
    );
  }

  static int pointsForTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'common':
        return 1;
      case 'uncommon':
        return 2;
      case 'rare':
        return 3;
      case 'epic':
        return 5;
      case 'legendary':
        return 10;
      case 'mythic':
        return 20;
      default:
        return 0;
    }
  }

  static String levelForPoints(int points) {
    if (points >= 220) return 'Mythic';
    if (points >= 150) return 'Master';
    if (points >= 100) return 'Expert';
    if (points >= 60) return 'Tracker';
    if (points >= 30) return 'Naturalist';
    if (points >= 10) return 'Explorer';
    return 'Novice';
  }

  static Set<String> _distinctValues(
    List<Species> species,
    String? Function(Species) getter,
  ) {
    final set = <String>{};
    for (final s in species) {
      final value = getter(s)?.trim().toLowerCase();
      if (value != null && value.isNotEmpty) {
        set.add(value);
      }
    }
    return set;
  }

  static _ParkProgress _parkProgress(
    List<ParkGuide> guides,
    Set<String> discoveredIds,
  ) {
    int bestCount = 0;
    bool anyComplete = false;
    for (final guide in guides) {
      if (guide.species.isEmpty) continue;
      final ids = guide.species.map((s) => s.id).toSet();
      final count = ids.intersection(discoveredIds).length;
      bestCount = count > bestCount ? count : bestCount;
      if (count == ids.length) {
        anyComplete = true;
      }
    }
    return _ParkProgress(bestCount: bestCount, anyComplete: anyComplete);
  }

  static Map<String, DateTime> _discoveriesByTimeOfDay(UserDataProvider userData) {
    final earliest = <String, DateTime>{};
    userData.allSightings.forEach((speciesId, sightings) {
      for (final sighting in sightings) {
        final existing = earliest[speciesId];
        if (existing == null || sighting.timestamp.isBefore(existing)) {
          earliest[speciesId] = sighting.timestamp;
        }
      }
    });
    return earliest;
  }

  static int _countTimeOfDay(
    Map<String, DateTime> earliestDiscovery,
    int startHour,
    int endHour,
  ) {
    int count = 0;
    for (final ts in earliestDiscovery.values) {
      final hour = ts.hour;
      final inRange = hour >= startHour && hour < endHour;
      if (inRange) count += 1;
    }
    return count;
  }
}

class _ParkProgress {
  final int bestCount;
  final bool anyComplete;

  _ParkProgress({required this.bestCount, required this.anyComplete});
}

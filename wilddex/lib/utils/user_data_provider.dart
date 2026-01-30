import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/species.dart';
import '../models/sighting.dart';

class UserDataProvider with ChangeNotifier {
  final Set<String> _discoveredSpeciesIds = {};
  final Map<String, List<Sighting>> _sightings = {};
  final Map<String, DateTime> _earnedBadges = {};
  late SharedPreferences _prefs;
  bool _isInitialized = false;
  bool _needsBadgeSync = true;

  // Getters
  bool get isInitialized => _isInitialized;
  int get discoveredSpeciesCount => _discoveredSpeciesIds.length;
  int get totalSightingsCount => _sightings.values.fold(0, (sum, sightings) => sum + sightings.length);
  Set<String> get discoveredSpeciesIds => Set.unmodifiable(_discoveredSpeciesIds);
  Map<String, List<Sighting>> get allSightings => Map.unmodifiable(_sightings);
  Map<String, DateTime> get earnedBadges => Map.unmodifiable(_earnedBadges);
  Set<String> get earnedBadgeIds => _earnedBadges.keys.toSet();
  bool get needsBadgeSync => _needsBadgeSync;

  /// Returns the list of discovered Species from the full species list.
  List<Species> getDiscoveredSpecies(List<Species> allSpecies) {
    return allSpecies.where((s) => _discoveredSpeciesIds.contains(s.id)).toList();
  }

  List<Sighting> getSightingsForSpecies(String speciesId) {
    return _sightings[speciesId] ?? [];
  }

  List<Sighting> get sightings {
    return _sightings.values.expand((sightings) => sightings).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  int? get streakDays {
    if (_sightings.isEmpty) return null;
    final dates = _sightings.values
        .expand((list) => list)
        .map((s) => DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (dates.isEmpty) return null;
    int streak = 1;
    for (int i = 1; i < dates.length; i++) {
      final prev = dates[i - 1];
      final current = dates[i];
      if (prev.difference(current).inDays == 1) {
        streak += 1;
      } else if (prev.difference(current).inDays > 1) {
        break;
      }
    }
    return streak;
  }

  DateTime? get lastDiscoveryDate {
    if (_sightings.isEmpty) return null;
    final all = _sightings.values.expand((list) => list).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.isEmpty ? null : all.first.timestamp;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    _loadData();
    _isInitialized = true;
  }

  void _loadData() {
    // Load discovered species
    final discoveredSpeciesJson = _prefs.getStringList('discoveredSpecies') ?? [];
    _discoveredSpeciesIds.addAll(discoveredSpeciesJson);
    
    // Load sightings
    final sightingsJson = _prefs.getString('sightings');
    if (sightingsJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(sightingsJson);
        _sightings.clear();
        decoded.forEach((speciesId, sightingsList) {
          _sightings[speciesId] = (sightingsList as List)
              .map((s) => Sighting.fromJson(s as Map<String, dynamic>))
              .toList();
        });
      } catch (e) {
        debugPrint('Error loading sightings: $e');
        _sightings.clear();
      }
    }

    final earnedBadgesJson = _prefs.getString('earnedBadges');
    if (earnedBadgesJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(earnedBadgesJson);
        _earnedBadges.clear();
        decoded.forEach((badgeId, ts) {
          final parsed = DateTime.tryParse(ts as String? ?? '');
          if (parsed != null) {
            _earnedBadges[badgeId] = parsed;
          }
        });
      } catch (e) {
        debugPrint('Error loading badges: $e');
        _earnedBadges.clear();
      }
    }
    
    notifyListeners();
  }

  Future<void> discoverSpecies(String speciesId) async {
    if (_discoveredSpeciesIds.add(speciesId)) {
      await _prefs.setStringList('discoveredSpecies', _discoveredSpeciesIds.toList());
      _needsBadgeSync = true;
      notifyListeners();
    }
  }

  Future<void> addSighting(String speciesId, String imagePath) async {
    final sighting = Sighting(
      imagePath: imagePath,
      timestamp: DateTime.now(),
    );
    
    if (!_sightings.containsKey(speciesId)) {
      _sightings[speciesId] = [];
    }
    _sightings[speciesId]!.add(sighting);
    
    // Save to preferences
    final Map<String, List<Map<String, dynamic>>> encodedSightings = {};
    _sightings.forEach((speciesId, sightings) {
      encodedSightings[speciesId] = sightings.map((s) => s.toJson()).toList();
    });
    await _prefs.setString('sightings', json.encode(encodedSightings));
    _needsBadgeSync = true;
    notifyListeners();
  }

  Future<bool> addSightingIfNew(String speciesId, String imagePath) async {
    final sightings = _sightings[speciesId] ?? [];
    if (sightings.any((s) => s.imagePath == imagePath)) {
      return false;
    }
    await addSighting(speciesId, imagePath);
    return true;
  }

  bool isSpeciesDiscovered(String speciesId) {
    return _discoveredSpeciesIds.contains(speciesId);
  }

  Future<void> awardBadges(List<String> badgeIds) async {
    bool updated = false;
    for (final id in badgeIds) {
      if (!_earnedBadges.containsKey(id)) {
        _earnedBadges[id] = DateTime.now();
        updated = true;
      }
    }
    if (updated) {
      final encoded = _earnedBadges.map((k, v) => MapEntry(k, v.toIso8601String()));
      await _prefs.setString('earnedBadges', json.encode(encoded));
      notifyListeners();
    }
  }

  void markBadgeSyncComplete() {
    _needsBadgeSync = false;
  }
}

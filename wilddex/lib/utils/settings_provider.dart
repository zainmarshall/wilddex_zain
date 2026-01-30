import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const _coreDexKey = 'coreDexEnabled';

  late SharedPreferences _prefs;
  bool _initialized = false;
  bool _useCoreDex = false;

  bool get isInitialized => _initialized;
  bool get useCoreDex => _useCoreDex;

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _useCoreDex = _prefs.getBool(_coreDexKey) ?? false;
    _initialized = true;
  }

  Future<void> setUseCoreDex(bool value) async {
    _useCoreDex = value;
    await _prefs.setBool(_coreDexKey, value);
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class SettingsProvider with ChangeNotifier {
  static const _coreDexKey = 'coreDexEnabled';
  static const _useLocalApiKey = 'useLocalApi';
  static const _localApiHostKey = 'localApiHost';
  static const _useCropModelKey = 'useCropModel';

  late SharedPreferences _prefs;
  bool _initialized = false;
  bool _useCoreDex = false;
  bool _useLocalApi = false;
  String _localApiHost = '';
  bool _useCropModel = false;

  bool get isInitialized => _initialized;
  bool get useCoreDex => _useCoreDex;
  bool get useLocalApi => _useLocalApi;
  String get localApiHost => _localApiHost;
  bool get useCropModel => _useCropModel;

  String get apiBaseUrl {
    if (!_useLocalApi) {
      return cloudApiBaseUrl;
    }
    final host = _localApiHost.trim();
    if (host.isEmpty) {
      return 'http://localhost:8000';
    }
    if (host.startsWith('http://') || host.startsWith('https://')) {
      return host;
    }
    return 'http://$host';
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _useCoreDex = _prefs.getBool(_coreDexKey) ?? false;
    _useLocalApi = _prefs.getBool(_useLocalApiKey) ?? false;
    _localApiHost = _prefs.getString(_localApiHostKey) ?? '';
    _useCropModel = _prefs.getBool(_useCropModelKey) ?? false;
    _initialized = true;
  }

  Future<void> setUseCoreDex(bool value) async {
    _useCoreDex = value;
    await _prefs.setBool(_coreDexKey, value);
    notifyListeners();
  }

  Future<void> setUseLocalApi(bool value) async {
    _useLocalApi = value;
    await _prefs.setBool(_useLocalApiKey, value);
    notifyListeners();
  }

  Future<void> setLocalApiHost(String value) async {
    _localApiHost = value.trim();
    await _prefs.setString(_localApiHostKey, _localApiHost);
    notifyListeners();
  }

  Future<void> setUseCropModel(bool value) async {
    _useCropModel = value;
    await _prefs.setBool(_useCropModelKey, value);
    notifyListeners();
  }
}

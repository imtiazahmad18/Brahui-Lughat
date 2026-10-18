import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small local persistence adapter. No network-backed storage is used.
class LocalDictionaryStorage {
  LocalDictionaryStorage(this._preferences);
  final SharedPreferences _preferences;

  static Future<LocalDictionaryStorage> open() async =>
      LocalDictionaryStorage(await SharedPreferences.getInstance());

  Set<int> loadSavedIds() =>
      (_preferences.getStringList('saved') ?? const []).map(int.parse).toSet();

  List<Map<String, dynamic>> loadHistory() =>
      (_preferences.getStringList('history') ?? const [])
          .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
          .toList();

  int get modeIndex => _preferences.getInt('mode') ?? 0;
  String get theme => _preferences.getString('theme') ?? 'dark';
  int get fontSizeIndex => _preferences.getInt('fontSize') ?? 1;

  /// Drops id-based collections when the bundled dictionary changes.
  Future<void> migrateData(String version) async {
    if (_preferences.getString('dataVersion') == version) return;
    await _preferences.setStringList('saved', const []);
    await _preferences.setStringList('history', const []);
    await _preferences.setString('dataVersion', version);
  }

  Future<void> saveCollections(
    Set<int> saved,
    List<Map<String, dynamic>> history,
  ) async {
    await _preferences.setStringList(
      'saved',
      saved.map((id) => '$id').toList(),
    );
    await _preferences.setStringList(
      'history',
      history.map(jsonEncode).toList(),
    );
  }

  Future<void> saveMode(int value) async {
    await _preferences.setInt('mode', value);
  }

  Future<void> saveTheme(String value) async {
    await _preferences.setString('theme', value);
  }

  Future<void> saveFontSize(int value) async {
    await _preferences.setInt('fontSize', value);
  }
}

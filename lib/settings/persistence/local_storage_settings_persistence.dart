import 'package:shared_preferences/shared_preferences.dart';

import 'settings_persistence.dart';

/// `shared_preferences`-backed [SettingsPersistence].
class LocalStorageSettingsPersistence extends SettingsPersistence {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  @override
  Future<bool> getAudioOn({required bool defaultValue}) async =>
      (await _prefs).getBool('audioOn') ?? defaultValue;

  @override
  Future<bool> getMusicOn({required bool defaultValue}) async =>
      (await _prefs).getBool('musicOn') ?? defaultValue;

  @override
  Future<bool> getSoundsOn({required bool defaultValue}) async =>
      (await _prefs).getBool('soundsOn') ?? defaultValue;

  @override
  Future<void> saveAudioOn(bool value) async =>
      (await _prefs).setBool('audioOn', value);

  @override
  Future<void> saveMusicOn(bool value) async =>
      (await _prefs).setBool('musicOn', value);

  @override
  Future<void> saveSoundsOn(bool value) async =>
      (await _prefs).setBool('soundsOn', value);
}

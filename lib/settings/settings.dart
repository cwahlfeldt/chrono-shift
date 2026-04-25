import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'persistence/local_storage_settings_persistence.dart';
import 'persistence/settings_persistence.dart';

/// Holds toggles for [audioOn], [musicOn], [soundsOn] and persists them to
/// the injected store.
class SettingsController {
  static final _log = Logger('SettingsController');

  final SettingsPersistence _store;

  /// Master mute. Wins over [musicOn] / [soundsOn] so a player can quickly
  /// silence the game without losing their per-channel preference.
  ValueNotifier<bool> audioOn = ValueNotifier(true);

  ValueNotifier<bool> soundsOn = ValueNotifier(true);
  ValueNotifier<bool> musicOn = ValueNotifier(true);

  SettingsController({SettingsPersistence? store})
    : _store = store ?? LocalStorageSettingsPersistence() {
    _loadStateFromPersistence();
  }

  void toggleAudioOn() {
    audioOn.value = !audioOn.value;
    _store.saveAudioOn(audioOn.value);
  }

  void toggleMusicOn() {
    musicOn.value = !musicOn.value;
    _store.saveMusicOn(musicOn.value);
  }

  void toggleSoundsOn() {
    soundsOn.value = !soundsOn.value;
    _store.saveSoundsOn(soundsOn.value);
  }

  Future<void> _loadStateFromPersistence() async {
    final loaded = await Future.wait([
      _store.getAudioOn(defaultValue: true).then((value) {
        // Web browsers refuse to start audio without a user gesture, so
        // we always boot muted on the web regardless of the saved value.
        return audioOn.value = kIsWeb ? false : value;
      }),
      _store
          .getSoundsOn(defaultValue: true)
          .then((value) => soundsOn.value = value),
      _store
          .getMusicOn(defaultValue: true)
          .then((value) => musicOn.value = value),
    ]);
    _log.fine(() => 'Loaded settings: $loaded');
  }
}

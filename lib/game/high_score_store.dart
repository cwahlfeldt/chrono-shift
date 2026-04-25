import 'package:shared_preferences/shared_preferences.dart';

/// Local-storage backed high-score store. Single source of truth for the
/// `chrono_high_score` key — every reader/writer goes through here.
class HighScoreStore {
  static const _key = 'chrono_high_score';

  Future<int> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  Future<void> save(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, score);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

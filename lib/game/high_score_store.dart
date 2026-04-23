import 'package:shared_preferences/shared_preferences.dart';

/// Simple local-storage backed high-score store for Chrono-Swipe.
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
}

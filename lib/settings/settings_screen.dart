import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../style/palette.dart';
import 'settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final palette = context.watch<Palette>();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        iconTheme: IconThemeData(color: palette.white),
        elevation: 0,
        title: Text(
          'SETTINGS',
          style: TextStyle(
            fontFamily: 'Permanent Marker',
            color: palette.white,
            letterSpacing: 4,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: settings.soundsOn,
                builder: (context, on, _) => _line(
                  palette,
                  'Sound FX',
                  on ? Icons.graphic_eq : Icons.volume_off,
                  on,
                  settings.toggleSoundsOn,
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: settings.musicOn,
                builder: (context, on, _) => _line(
                  palette,
                  'Music',
                  on ? Icons.music_note : Icons.music_off,
                  on,
                  settings.toggleMusicOn,
                ),
              ),
              const SizedBox(height: 24),
              _line(
                palette,
                'Reset best score',
                Icons.delete_outline,
                false,
                () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('chrono_high_score');
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Best score reset.')),
                  );
                },
              ),
              const SizedBox(height: 40),
              Center(
                child: GestureDetector(
                  onTap: () => GoRouter.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 36, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: palette.cyan),
                    ),
                    child: Text(
                      'BACK',
                      style: TextStyle(
                        color: palette.cyan,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(Palette palette, String title, IconData icon, bool active,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (active ? palette.cyan : palette.dim).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: palette.white,
                  fontSize: 18,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(icon,
                color: active ? palette.cyan : palette.dim, size: 24),
          ],
        ),
      ),
    );
  }
}

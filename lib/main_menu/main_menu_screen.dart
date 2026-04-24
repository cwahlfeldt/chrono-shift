import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_controller.dart';
import '../audio/sounds.dart';
import '../game/idle_backdrop.dart';
import '../settings/settings.dart';
import '../style/palette.dart';

/// Main menu for Chrono-Swipe: animated backdrop (starfield + track), big
/// title, best-score, play button, and a small row of secondary controls.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _best = 0;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt('chrono_high_score') ?? 0;
    if (mounted && v != _best) setState(() => _best = v);
  }

  @override
  Widget build(BuildContext context) {
    // go_router keeps this screen in the tree under /play, so initState
    // doesn't re-run when the player returns from a run. Re-read the
    // stored best on each build — SharedPreferences is cached after the
    // first hit, so it's effectively free.
    _loadBest();
    final palette = context.watch<Palette>();
    final settings = context.watch<SettingsController>();

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const IdleBackdrop(),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _menuColumn(context, palette, settings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuColumn(
    BuildContext context,
    Palette palette,
    SettingsController settings,
  ) {
    return Column(
      children: [
        const Spacer(flex: 2),
        Text(
          'CHRONO',
          style: TextStyle(
            fontFamily: 'Krona One',
            fontSize: 54,
            height: 0.95,
            color: palette.white,
            // letterSpacing: 2,
            shadows: [
              Shadow(
                color: palette.cyan.withValues(alpha: 0.9),
                blurRadius: 24,
              ),
            ],
          ),
        ),
        Text(
          'SHIFT',
          style: TextStyle(
            fontFamily: 'Krona One',
            fontSize: 54,
            height: 0.95,
            color: palette.cyan,
            letterSpacing: 24,
            shadows: [
              Shadow(
                color: palette.gold.withValues(alpha: 0.8),
                blurRadius: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Slow time & make it out alive.',
          style: TextStyle(color: palette.dim, fontSize: 14, letterSpacing: 2),
        ),
        const Spacer(flex: 3),
        _bigPlayButton(context, palette),
        const SizedBox(height: 24),
        if (_best > 0)
          Text(
            'BEST  $_best',
            style: TextStyle(
              color: palette.gold,
              fontFamily: 'Krona One',
              fontSize: 20,
              letterSpacing: 4,
            ),
          ),
        const Spacer(flex: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: settings.audioOn,
              builder: (context, audioOn, _) => IconButton(
                iconSize: 26,
                color: palette.dim,
                onPressed: settings.toggleAudioOn,
                icon: Icon(audioOn ? Icons.volume_up : Icons.volume_off),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 26,
              color: palette.dim,
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bigPlayButton(BuildContext context, Palette palette) {
    return GestureDetector(
      onTap: () {
        try {
          context.read<AudioController>().playSfx(SfxType.buttonTap);
        } catch (_) {}
        context.go('/play');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
        decoration: BoxDecoration(
          color: palette.cyan.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.cyan, width: 2),
          // boxShadow: [
          //   BoxShadow(
          //     color: palette.cyan.withValues(alpha: 0.6),
          //     blurRadius: 30,
          //   ),
          // ],
        ),
        child: Text(
          'PLAY',
          style: TextStyle(
            fontFamily: 'Krona One',
            fontSize: 28,
            color: palette.white,
            letterSpacing: 8,
          ),
        ),
      ),
    );
  }
}

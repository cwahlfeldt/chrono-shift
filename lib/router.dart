import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'game/play_screen.dart';
import 'main_menu/main_menu_screen.dart';
import 'settings/settings_screen.dart';

/// Router for Chrono-Swipe. Three screens: main menu, play, and settings.
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainMenuScreen(key: Key('main menu')),
      routes: [
        GoRoute(
          path: 'play',
          builder: (context, state) => const PlayScreen(key: Key('play')),
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) =>
              const SettingsScreen(key: Key('settings')),
        ),
      ],
    ),
  ],
);

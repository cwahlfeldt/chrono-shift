# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Chrono-Swipe** — a Flutter arcade survival game. One-finger play: drag to steer a light through a procedural obstacle corridor, hold to activate **Chrono-Shift** (slow-motion, drains a finite meter). See [GAME.md](GAME.md) for the full design doc — it is the source of truth for feel, scoring, and difficulty curve, and is worth re-reading before changing tuning numbers.

Note: `pubspec.yaml` still uses the template's package name `basic` (so imports are `package:basic/...`). The app class is `ChronoSwipeApp`.

## Commands

```bash
flutter run                      # debug on default device
flutter run -d macos             # desktop dev loop (fastest iteration)
flutter test                     # all tests
flutter test test/smoke_test.dart -p vm  # single test file
flutter analyze                  # lints + strict-casts analyzer (see analysis_options.yaml)
flutter build ipa                # iOS release
flutter build appbundle          # Android release
```

The macOS desktop target is the quickest way to iterate on gameplay — keyboard controls (arrow keys / A-D to steer, Space/Shift to Chrono-Shift) are wired up specifically so you don't need a touch device.

## Architecture

### Game loop (`lib/game/`)

All gameplay lives here. It is **not** built on Flame or any game engine — it is a plain `Ticker` + `CustomPainter` + `ChangeNotifier` stack.

- [lib/game/game_state.dart](lib/game/game_state.dart) — `GameState extends ChangeNotifier` owns **all** simulation state and tuning constants (speed, meter drain/fill, near-miss thresholds, difficulty curve, obstacle spawning). When tweaking feel, this is almost always the file you want. Pure Dart — no Flutter widget imports beyond `Color`/`Size`.
- [lib/game/play_screen.dart](lib/game/play_screen.dart) — owns the `Ticker`, translates pointer/keyboard input into `GameState` calls, and renders the HUD + game-over card on top of the painter. Holds the `_chronoHoldSeconds` guard (~50ms) that distinguishes a hold from a drag.
- [lib/game/game_painter.dart](lib/game/game_painter.dart) — `CustomPainter` that reads from `GameState` (via `super(repaint: state)`) and draws background, stars, obstacles, trail, player, particles, and the chrono tint overlay.
- [lib/game/models.dart](lib/game/models.dart) — `Obstacle`, `Particle`, `Star`, `TrailSample`. Obstacles are either walls (with gap) or pillars.
- [lib/game/idle_backdrop.dart](lib/game/idle_backdrop.dart) — reuses `GameState` in a non-running "idle" mode (`idleTick`) to drive the main-menu starfield.
- [lib/game/high_score_store.dart](lib/game/high_score_store.dart) — trivial `shared_preferences` wrapper (`chrono_high_score` key).

### World coordinate system

Critical mental model for anything touching obstacles or rendering:

- The world has a forward **`worldY`** axis. Obstacles are placed at fixed `worldY` and never move; they appear to scroll because the player's `distance` grows.
- Projection: `screenY = viewH - playerBase - (worldY - distance)`.
- The viewport is pushed into `GameState` by the painter (`state.setViewport(size)` in `paint`) rather than coming from the widget tree directly. Spawn logic and collision checks all key off `viewW`/`viewH` set this way, so `GameState` stays testable without a render pass.
- `timeScale` smooths toward `1.0` or `slowFactor` (0.2). Game-sim `dt = realDt * timeScale`, but **steering and the meter drain/fill use real `dt`** — slow-mo must not make steering mushy or make the meter trivially refillable.

### App shell (template leftovers)

The non-game directories came from the official Flutter games template and were kept because they already work. Don't rebuild them:

- [lib/main.dart](lib/main.dart) — `ChronoSwipeApp` wires up `AppLifecycleObserver`, `Provider`s for `SettingsController` / `Palette` / `AudioController`, and `MaterialApp.router`. Logging is set up here (`dart:developer` sink).
- [lib/router.dart](lib/router.dart) — three `go_router` routes: `/` (main menu), `/play`, `/settings`.
- [lib/audio/](lib/audio/), [lib/app_lifecycle/](lib/app_lifecycle/), [lib/settings/](lib/settings/), [lib/style/palette.dart](lib/style/palette.dart), [lib/main_menu/](lib/main_menu/) — audio facade over `audioplayers`, lifecycle listener that pauses audio, settings persistence via `shared_preferences`, palette, menu screen.

### State management

`provider` for DI (settings, palette, audio). Game state is **not** exposed through `provider` — `PlayScreen` owns its own `GameState` in a `late final` field and disposes it. Don't lift it into a provider; tests and idle-backdrop reuse rely on being able to instantiate a fresh `GameState` directly.

## Tuning the game

Almost every feel knob is a `static const` at the top of `GameState`:

- **Speed & difficulty**: `baseSpeed`, `speedDistBoost`, `speedDistBoostCap`, `_difficulty()` (distance → 0..1.6).
- **Chrono meter**: `slowFactor`, `meterDrainPerSec`, `meterFillPerSec`, `meterRefundTier{1,2,3}`.
- **Steering**: `steerFollow` / `steerFollowChrono` (lerp factors applied with *real* dt), `keyboardSteer`.
- **Near-miss**: `nearMissTier{1,2,3}`, `pillarNearMissTier{1,2}`, `streakPerMiss`, `streakDecaySeconds`, `maxStreakSteps`.
- **Scoring**: `scorePerPx`, in-tick `chronoScale` = 2.2 for the slow-mo multiplier.

Obstacle mix and unlock order live in `_spawnObstacles` / `_spawnOne` (`_Kind` enum: `wall`, `slab`, `comb`, `diag`). Walls-only until `_difficulty() >= 0.15`; combs unlock at `0.35`.

## Testing

Only [test/smoke_test.dart](test/smoke_test.dart) exists — it pumps `ChronoSwipeApp` and checks the main-menu text renders. There are no gameplay tests yet. `GameState` is structured to be testable (pure Dart, viewport injected) if you add any.

## Repo state caveats

The working tree has many deletions of old template screens (`level_selection/`, `play_session/`, `player_progress/`, `win_game/`, etc.) that have been replaced by `lib/game/` but not yet committed. Only one commit exists (`init`). If you see references to the old paths in generated platform files (`macos/Flutter/GeneratedPluginRegistrant.swift`, `linux/flutter/generated_plugins.cmake`, etc.), those are mid-migration — regenerate via `flutter pub get` / platform rebuilds rather than hand-editing.

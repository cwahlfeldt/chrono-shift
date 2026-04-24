import 'package:chrono_shift/game/game_painter.dart';
import 'package:chrono_shift/game/game_state.dart';
import 'package:chrono_shift/game/game_tuning.dart';
import 'package:chrono_shift/game/models.dart';
import 'package:chrono_shift/style/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden-image tests for [GamePainter].
///
/// These lock in the visual output of key frames — idle starfield, a
/// mid-run frame with a handful of obstacles and a trail, and the crash
/// frame with particles. A refactor that changes pixel-level output will
/// surface here as a diff. When the change is intentional, regenerate
/// with `flutter test --update-goldens test/golden_painter_test.dart`.
///
/// Notes:
///  - Baselines were generated on macOS with Impeller. Running on a
///    different host/renderer (e.g. a Linux CI) may produce sub-pixel
///    differences in blurs and gradients. If CI picks up these tests,
///    either pin generation to one host or introduce a tolerant
///    comparator.
///  - All randomness is avoided by building obstacles/stars by hand —
///    the shared `rng` in models.dart is not reseeded.
const Size _canvasSize = Size(400, 800);

void main() {
  // Palette is deterministic (compile-time constants).
  final palette = Palette();

  Widget wrapPainter(GameState state) {
    return MediaQuery(
      data: const MediaQueryData(size: _canvasSize),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          width: _canvasSize.width,
          height: _canvasSize.height,
          color: const Color(0xff000000),
          child: CustomPaint(
            size: _canvasSize,
            painter: GamePainter(state: state, palette: palette),
          ),
        ),
      ),
    );
  }

  // Build a GameState with a fixed star layout and no obstacles. Avoids
  // the rng-seeded starfield that reset() would generate.
  GameState idleState() {
    final s = GameState();
    s.setViewport(_canvasSize);
    // Skip reset() so we don't seed random stars; build them ourselves.
    s.stars.clear();
    // Deterministic grid-ish starfield.
    for (var i = 0; i < 80; i++) {
      final row = i ~/ 10;
      final col = i % 10;
      s.stars.add(Star(
        (col + 0.5) / 10,
        (row + 0.5) / 8,
        0.2 + ((i * 37) % 80) / 100.0,
      ));
    }
    s.playerX = _canvasSize.width / 2;
    s.playerXTarget = s.playerX;
    return s;
  }

  GameState midRunState() {
    final s = idleState();
    s.running = true;
    s.distance = 3000;
    s.playerX = _canvasSize.width / 2 - 30;
    s.playerXTarget = s.playerX;
    s.meter = 0.7;

    // A few hand-placed obstacles spanning the visible runway.
    const cyan = Color(0xff2ff3e0);
    s.obstacles.add(Obstacle.wall(
      worldY: s.distance + 200,
      thickness: 28,
      gapX: _canvasSize.width / 2,
      gap: 140,
      color: cyan,
    ));
    s.obstacles.add(Obstacle.wall(
      worldY: s.distance + 520,
      thickness: 28,
      gapX: _canvasSize.width / 2 + 60,
      gap: 120,
      color: cyan,
    ));
    s.obstacles.add(Obstacle.pillar(
      worldY: s.distance + 800,
      thickness: 32,
      x: _canvasSize.width / 2 - 80,
      halfW: 24,
      color: cyan,
    ));

    // A trail behind the player.
    final py = _canvasSize.height - GameTuning.playerBase;
    for (var i = 0; i < 30; i++) {
      final t = i / 30;
      s.trail.add(TrailSample(
        s.playerX - (1 - t) * 20,
        py + (1 - t) * 40,
        false,
      ));
    }
    return s;
  }

  GameState crashState() {
    final s = midRunState();
    s.gameOver = true;
    s.flashOpacity = 0.6;
    s.shake = 0.0; // zero out shake for deterministic output
    // A handful of explosion particles.
    const colors = [
      Color(0xffff4d6d),
      Color(0xffffd166),
      Color(0xff7cf7ff),
    ];
    final cx = s.playerX;
    final cy = _canvasSize.height - GameTuning.playerBase;
    for (var i = 0; i < 30; i++) {
      final ang = i * 0.41;
      s.particles.add(Particle(
        x: cx + 40 * (i % 5 - 2).toDouble(),
        y: cy + 30 * (i % 4 - 1).toDouble(),
        vx: 0,
        vy: 0,
        life: 0.5,
        maxLife: 1.0,
        radius: 2.5,
        color: colors[i % 3],
      ));
      // quiet the analyzer — keep `ang` used for future variation.
      if (ang.isNaN) break;
    }
    return s;
  }

  testWidgets('golden: idle backdrop', (tester) async {
    await tester.pumpWidget(wrapPainter(idleState()));
    await expectLater(
      find.byType(CustomPaint).first,
      matchesGoldenFile('goldens/idle_backdrop.png'),
    );
  });

  testWidgets('golden: mid-run with obstacles', (tester) async {
    await tester.pumpWidget(wrapPainter(midRunState()));
    await expectLater(
      find.byType(CustomPaint).first,
      matchesGoldenFile('goldens/mid_run.png'),
    );
  });

  testWidgets('golden: crash frame', (tester) async {
    await tester.pumpWidget(wrapPainter(crashState()));
    await expectLater(
      find.byType(CustomPaint).first,
      matchesGoldenFile('goldens/crash.png'),
    );
  });
}

import 'dart:ui' show Color, Size;

import 'package:chrono_shift/game/game_state.dart';
import 'package:chrono_shift/game/game_tuning.dart';
import 'package:chrono_shift/game/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure-Dart simulation tests. GameState is engine-free and viewport-
/// injected, so everything here runs without pumping widgets.
///
/// The viewport chosen (400 x 800) is a reasonable phone-portrait ratio
/// and keeps player-base math inside the visible area.
const Size _viewport = Size(400, 800);

GameState _freshState() {
  final s = GameState();
  s.setViewport(_viewport);
  s.reset();
  return s;
}

void main() {
  group('difficulty curve', () {
    test('is non-decreasing across the full range', () {
      double prev = GameState.difficultyAt(0);
      for (var d = 0.0; d <= 30000; d += 250) {
        final cur = GameState.difficultyAt(d);
        expect(cur, greaterThanOrEqualTo(prev),
            reason: 'difficulty dipped at d=$d ($prev -> $cur)');
        prev = cur;
      }
    });

    test('starts at 0 and saturates at 1.6', () {
      expect(GameState.difficultyAt(0), 0.0);
      expect(GameState.difficultyAt(12000), closeTo(1.0, 1e-9));
      // Far past the cap — should still be clamped.
      expect(GameState.difficultyAt(1e9), 1.6);
    });

    test('key gameplay gates fall at expected distances', () {
      // Walls-only until 0.15 — that's d = 1800.
      expect(GameState.difficultyAt(1799), lessThan(0.15));
      expect(GameState.difficultyAt(1801), greaterThanOrEqualTo(0.15));
      // Combs unlock at 0.35 — that's d = 4200.
      expect(GameState.difficultyAt(4199), lessThan(0.35));
      expect(GameState.difficultyAt(4201), greaterThanOrEqualTo(0.35));
    });
  });

  group('per-swipe burst meter', () {
    // All meter tests silence the obstacle spawner so the run doesn't
    // end before the assertion window.
    void silenceSpawner(GameState s) {
      s.obstacles.clear();
      s.nextObstacleAt = s.distance + 1e9;
    }

    test('does not passively refill while chrono inactive', () {
      final s = _freshState();
      silenceSpawner(s);
      s.meter = 0.3;
      const dt = 1 / 60;
      for (var i = 0; i < 60 * 4; i++) {
        s.tick(dt);
        if (s.gameOver) break;
      }
      expect(s.meter, 0.3);
      expect(s.gameOver, isFalse);
    });

    test('fresh activation refills meter to 1.0', () {
      final s = _freshState();
      silenceSpawner(s);
      s.meter = 0.1;
      s.setChronoActive(true);
      expect(s.meter, 1.0);
      expect(s.chronoActive, isTrue);
    });

    test('drains while chrono active', () {
      final s = _freshState();
      silenceSpawner(s);
      s.setChronoActive(true);
      const dt = 1 / 60;
      // 1 second of drain.
      for (var i = 0; i < 60; i++) {
        s.tick(dt);
        if (s.gameOver) break;
      }
      final drained = 1.0 - s.meter;
      expect(drained, closeTo(GameTuning.meterDrainPerSec, 0.05));
    });

    test('auto-disables chrono when meter empties', () {
      final s = _freshState();
      silenceSpawner(s);
      s.setChronoActive(true);
      s.meter = 0.05;
      const dt = 1 / 60;
      for (var i = 0; i < 60 * 2; i++) {
        s.tick(dt);
        if (!s.chronoActive) break;
      }
      expect(s.chronoActive, isFalse);
      expect(s.meter, 0.0);
    });

    test('re-activating after empty refills the burst', () {
      final s = _freshState();
      silenceSpawner(s);
      s.setChronoActive(true);
      // Drain the burst naturally.
      const dt = 1 / 60;
      for (var i = 0; i < 60 * 5; i++) {
        s.tick(dt);
        if (!s.chronoActive) break;
      }
      expect(s.chronoActive, isFalse);
      expect(s.meter, 0.0);
      // A fresh swipe must give a full burst again.
      s.setChronoActive(true);
      expect(s.meter, 1.0);
      expect(s.chronoActive, isTrue);
    });
  });

  group('collision edge cases', () {
    // We drive collisions by manually placing a single obstacle directly
    // in the player's path, then ticking until it reaches the player.
    //
    // [runUntilCrashOrCleared] ticks up to [maxSteps] frames or returns
    // early if the game either crashes or scrolls the obstacle past.

    bool runUntilCrashOrCleared(GameState s, {int maxSteps = 600}) {
      const dt = 1 / 60;
      for (var i = 0; i < maxSteps; i++) {
        s.tick(dt);
        if (s.gameOver) return true;
        // Cleared = the obstacle has scrolled well behind.
        if (s.obstacles.isEmpty) return false;
      }
      return s.gameOver;
    }

    void clearSpawned(GameState s) {
      // reset() runs the first spawn pass; we don't want its noise.
      s.obstacles.clear();
      // Push the next spawn world-Y far ahead so the spawner stays
      // quiet for the duration of the test.
      s.nextObstacleAt = s.distance + 1e9;
    }

    test('player centered in wall gap does not crash', () {
      final s = _freshState();
      clearSpawned(s);
      // Place a wall right ahead of the player, gap exactly centered.
      final playerY = s.playerX;
      s.obstacles.add(Obstacle.wall(
        worldY: s.distance + 200, // a bit ahead
        thickness: 24,
        gapX: playerY, // same x as player
        gap: 120,
        color: const Color(0xff00ffff),
      ));
      final crashed = runUntilCrashOrCleared(s);
      expect(crashed, isFalse,
          reason: 'centered in gap should never crash');
    });

    test('player aligned with wall body crashes', () {
      final s = _freshState();
      clearSpawned(s);
      // Place a wall with its gap far from the player so the player's x
      // lands on the wall body.
      s.obstacles.add(Obstacle.wall(
        worldY: s.distance + 200,
        thickness: 24,
        gapX: s.playerX + 200, // gap off to the right, beyond viewport
        gap: 80,
        color: const Color(0xff00ffff),
      ));
      final crashed = runUntilCrashOrCleared(s);
      expect(crashed, isTrue);
    });

    test('pillar directly under player crashes', () {
      final s = _freshState();
      clearSpawned(s);
      s.obstacles.add(Obstacle.pillar(
        worldY: s.distance + 200,
        thickness: 24,
        x: s.playerX,
        halfW: 20,
        color: const Color(0xff00ffff),
      ));
      final crashed = runUntilCrashOrCleared(s);
      expect(crashed, isTrue);
    });

    test('pillar well off to the side does not crash', () {
      final s = _freshState();
      clearSpawned(s);
      s.obstacles.add(Obstacle.pillar(
        worldY: s.distance + 200,
        thickness: 24,
        x: s.playerX + 150, // far to the right
        halfW: 20,
        color: const Color(0xff00ffff),
      ));
      final crashed = runUntilCrashOrCleared(s);
      expect(crashed, isFalse);
    });

    test('gap exactly the width of (2*playerRadius + slack) is survivable', () {
      final s = _freshState();
      clearSpawned(s);
      // The _hits check rejects if px-r > gapL && px+r < gapR, i.e. the
      // player's full circle must fit strictly inside the gap. So a
      // perfectly-centered player with gap = 2*r + small slack must
      // survive.
      const slack = 2.0;
      final gap = GameTuning.playerRadius * 2 + slack;
      s.obstacles.add(Obstacle.wall(
        worldY: s.distance + 200,
        thickness: 24,
        gapX: s.playerX,
        gap: gap,
        color: const Color(0xff00ffff),
      ));
      final crashed = runUntilCrashOrCleared(s);
      expect(crashed, isFalse);
    });
  });

  group('near-miss tiers', () {
    // Drive one obstacle past the player with the player offset from the
    // gap center by a known amount, and check the awarded tier via
    // nearMissFlash text + nearMisses counter.

    void stageWallAtDistance(GameState s, double playerOffsetFromGap,
        {double gap = 200}) {
      s.obstacles.clear();
      s.nextObstacleAt = s.distance + 1e9; // silence the spawner
      // Put the gap at playerX + offset, so the closest edge is at
      // offset - gap/2 or offset + gap/2; `closest` in the sim is
      // min(|px - gapL|, |px - gapR|) = min(|offset + gap/2|,
      // |offset - gap/2|). When offset is small vs. gap/2, both edges
      // are ~gap/2 away. To get a specific "closest-edge distance = d",
      // we set offset = gap/2 - d so the near edge is exactly d away.
      s.obstacles.add(Obstacle.wall(
        worldY: s.distance + 40, // just ahead
        thickness: 4, // thin so we pass it without colliding
        gapX: s.playerX + playerOffsetFromGap,
        gap: gap,
        color: const Color(0xff00ffff),
      ));
    }

    // Drive state by ticking a few frames so _cullAndAwardNearMiss runs.
    void runFew(GameState s) {
      const dt = 1 / 60;
      for (var i = 0; i < 10; i++) {
        s.tick(dt);
        if (s.gameOver) break;
      }
    }

    test('tier 3 (PERFECT) fires inside nearMissTier3', () {
      final s = _freshState();
      // closest-edge distance = gap/2 - offset. Want d < tier3 (16)
      // but > playerRadius so we don't collide. d = 13 works.
      const gap = 200.0;
      const d = 13.0;
      stageWallAtDistance(s, gap / 2 - d, gap: gap);
      runFew(s);
      expect(s.gameOver, isFalse);
      expect(s.nearMisses, 1);
      expect(s.nearMissFlash, 'PERFECT');
    });

    test('tier 2 fires between tier3 and tier2 thresholds', () {
      final s = _freshState();
      const gap = 200.0;
      const d = 22.0; // between 16 and 28
      stageWallAtDistance(s, gap / 2 - d, gap: gap);
      runFew(s);
      expect(s.nearMisses, 1);
      expect(s.nearMissFlash, 'NEAR MISS');
    });

    test('tier 1 fires between tier2 and tier1 thresholds', () {
      final s = _freshState();
      const gap = 200.0;
      const d = 36.0; // between 28 and 44
      stageWallAtDistance(s, gap / 2 - d, gap: gap);
      runFew(s);
      expect(s.nearMisses, 1);
      expect(s.nearMissFlash, 'NEAR MISS');
    });

    test('no near-miss awarded past tier1 threshold', () {
      final s = _freshState();
      const gap = 200.0;
      const d = 60.0; // > 44
      stageWallAtDistance(s, gap / 2 - d, gap: gap);
      runFew(s);
      expect(s.nearMisses, 0);
    });

    test('near-miss does not refund the meter', () {
      final s = _freshState();
      s.meter = 0.5;
      const gap = 200.0;
      const d = 13.0; // tier 3
      stageWallAtDistance(s, gap / 2 - d, gap: gap);
      runFew(s);
      expect(s.nearMisses, 1);
      // Burst economy: meter is only changed by activation/drain,
      // never by near-misses.
      expect(s.meter, 0.5);
    });
  });
}

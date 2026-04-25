import 'dart:math';
import 'dart:ui' show Color, Size;

import 'package:flutter/foundation.dart';

import 'game_tuning.dart';
import 'models.dart';

/// State of a single Chrono-Swipe run, top-down 2D. The world has a
/// forward "world-Y" axis that grows as the player advances. Obstacles
/// live at fixed world-Y positions; they appear to scroll down the screen
/// because we project `screenY = viewH - playerBase - (worldY - distance)`.
///
/// All positions are in logical pixels against the viewport size we were
/// last told about via [setViewport]. That keeps the game independent of
/// the Flutter layout pass that actually draws the frame.
class GameState extends ChangeNotifier {
  GameState();

  // All tunable feel-knobs live in [GameTuning]. This class only owns
  // simulation state.

  // ---------------------- Viewport ----------------------
  double viewW = 0.0;
  double viewH = 0.0;

  void setViewport(Size size) {
    if (size.width == viewW && size.height == viewH) return;
    final hadViewport = viewW > 0;
    viewW = size.width;
    viewH = size.height;
    // Re-center the player/target horizontally on the first real layout.
    if (!hadViewport) {
      playerX = viewW / 2;
      playerXTarget = viewW / 2;
      nextObstacleAt = viewH * 1.2;
    }
  }

  // ---------------------- Live state ----------------------
  bool running = false;
  bool gameOver = false;

  double realTime = 0.0;    // real (wall) seconds since run started
  double gameTime = 0.0;    // dilated seconds (advances slower during slow-mo)
  double timeScale = 1.0;   // smoothed toward 1.0 or slowFactor
  double meter = 1.0;       // 0..1
  bool chronoActive = false;

  /// Blend for star trails. Eases toward 1.0 normally and 0.0 while
  /// chrono is active. Decays slower than timeScale so the trail
  /// recedes gradually rather than snapping off.
  double starTrailBlend = 1.0;

  /// Ramps forward speed from 0 to 1 at the start of a run. The first
  /// few frames after the countdown ends use this to avoid a jarring
  /// instant jump from the idle creep to full speed. Set to 0 when a
  /// run begins; eases toward 1 via [tick].
  double introSpeedRamp = 1.0;

  double distance = 0.0;    // world-Y travelled (pixels)
  double playerX = 0.0;     // screen x
  double playerXTarget = 0.0;

  /// Optional override for the player's screen-y. When null the
  /// painter uses the standard `viewH - playerBase`. Used by the
  /// PlayScreen intro to slide the player up from below.
  double? playerYOverride;

  double score = 0.0;
  int nearMisses = 0;
  int streakSteps = 0;
  double streakMultiplier = 1.0;
  double _streakTimer = 0.0;

  String? nearMissFlash;
  double _nearMissFlashTimer = 0.0;

  // Last chrono refund, for a transient HUD indicator.
  double meterRefundAmount = 0.0;
  double meterRefundTimer = 0.0;

  // Crash overlays.
  double shake = 0.0;
  double flashOpacity = 0.0;

  final List<Obstacle> obstacles = [];
  final List<Particle> particles = [];
  final List<Star> stars = [];
  final List<TrailSample> trail = [];
  static const int _maxTrail = 60;

  double nextObstacleAt = 0.0;

  int highScore = 0;

  // ---------------------- Lifecycle ----------------------

  /// Seeds just enough state for [idleTick] / the menu backdrop:
  /// stars exist, no run is in progress, no obstacles or trail.
  void seedIdle() {
    reset();
    running = false;
    gameOver = false;
    obstacles.clear();
    trail.clear();
  }

  void reset() {
    running = true;
    gameOver = false;
    realTime = 0.0;
    gameTime = 0.0;
    timeScale = 1.0;
    meter = 1.0;
    chronoActive = false;
    starTrailBlend = 1.0;
    introSpeedRamp = 1.0;
    distance = 0.0;
    playerX = viewW / 2;
    playerXTarget = viewW / 2;
    playerYOverride = null;
    score = 0.0;
    nearMisses = 0;
    streakSteps = 0;
    streakMultiplier = 1.0;
    _streakTimer = 0.0;
    nearMissFlash = null;
    _nearMissFlashTimer = 0.0;
    meterRefundAmount = 0.0;
    meterRefundTimer = 0.0;
    shake = 0.0;
    flashOpacity = 0.0;
    obstacles.clear();
    particles.clear();
    trail.clear();
    nextObstacleAt = (viewH > 0 ? viewH : 800) * 1.2;

    if (stars.isEmpty) {
      // Deterministic seed so the starfield is identical across
      // GameState instances — lets the menu backdrop and the play
      // screen share the same visual frame at the route transition.
      final seeded = Random(1999);
      for (var i = 0; i < 80; i++) {
        stars.add(Star(seeded.nextDouble(), seeded.nextDouble(),
            0.2 + seeded.nextDouble() * 0.8));
      }
    }

    notifyListeners();
  }

  /// Direct-drag target. Caller passes an absolute screen-x.
  void setSteerTarget(double x) {
    playerXTarget = _clampPlayerX(x);
  }

  /// Delta from a pointer move; scaled 1:1 into target.
  void addSteerDelta(double dx) {
    playerXTarget = _clampPlayerX(playerXTarget + dx);
  }

  /// Keyboard nudge (direction = -1 or +1).
  void nudgeSteer(double direction, double realDt) {
    playerXTarget = _clampPlayerX(
        playerXTarget + direction * GameTuning.keyboardSteer * realDt);
  }

  void setChronoActive(bool active) {
    if (gameOver || !running) return;
    if (active && meter <= 0.02) return;
    chronoActive = active;
  }

  double _clampPlayerX(double x) {
    final lo = GameTuning.trackMargin + GameTuning.playerRadius + 4;
    final hi = viewW - GameTuning.trackMargin - GameTuning.playerRadius - 4;
    if (hi <= lo) return viewW / 2;
    return x.clamp(lo, hi);
  }

  // ---------------------- Tick ----------------------
  void tick(double realDt) {
    if (!running) return;
    realTime += realDt;

    _updateMeter(realDt);
    _updateTimeScale(realDt);
    final dt = realDt * timeScale;
    gameTime += dt;

    // Ease the intro ramp toward 1.0. Used to smoothly transition
    // from the (near-still) intro idle drift into full forward speed.
    // Rate ~2/s → roughly 0.5s to reach full speed, with the feel
    // front-loaded by the multiplicative lerp.
    if (introSpeedRamp < 1.0) {
      introSpeedRamp = min(
        1.0,
        introSpeedRamp + (1.0 - introSpeedRamp) * min(1.0, realDt * 2.5),
      );
    }

    if (!gameOver) {
      // Forward speed. Scaled by introSpeedRamp so a run doesn't start
      // with a jarring instant jump from idle creep.
      final fwd = (GameTuning.baseSpeed +
              min(GameTuning.speedDistBoostCap,
                  distance * GameTuning.speedDistBoost)) *
          introSpeedRamp;
      distance += fwd * dt;

      // Steering — real-time follow so slow-mo doesn't make steering mushy.
      final k =
          chronoActive ? GameTuning.steerFollowChrono : GameTuning.steerFollow;
      playerX += (playerXTarget - playerX) * min(1.0, realDt * k);
      playerX = _clampPlayerX(playerX);

      // Score.
      final chronoScale = chronoActive ? GameTuning.chronoScoreScale : 1.0;
      score +=
          fwd * dt * GameTuning.scorePerPx * chronoScale * streakMultiplier;

      _spawnObstacles();
      _cullAndAwardNearMiss();
      _checkCollisions();
      _updateTrail();
      _decayStreak();
    } else {
      // Brief fade-out after crash.
      flashOpacity = (flashOpacity - realDt * 2.0).clamp(0.0, 1.0);
    }

    _tickParticles(realDt);
    _tickStars(realDt);

    shake *= pow(0.001, realDt).toDouble();

    if (_nearMissFlashTimer > 0) {
      _nearMissFlashTimer -= realDt;
      if (_nearMissFlashTimer <= 0) nearMissFlash = null;
    }

    if (meterRefundTimer > 0) {
      meterRefundTimer -= realDt;
      if (meterRefundTimer <= 0) meterRefundAmount = 0.0;
    }

    notifyListeners();
  }

  /// Idle drift — used by the menu backdrop and the PlayScreen intro.
  /// Stars + forward illusion, no obstacles, no scoring.
  ///
  /// [speedScale] multiplies the baseline drift; the PlayScreen intro
  /// uses a small value so the world barely creeps before the run
  /// starts, while the menu uses the default.
  void idleTick(double realDt, {double speedScale = 1.0}) {
    timeScale = 1.0;
    distance += 80 * realDt * speedScale;
    _tickStars(realDt);
    notifyListeners();
  }

  // ---------------------- Sub-steps ----------------------
  void _updateMeter(double realDt) {
    if (chronoActive && meter > 0) {
      meter = max(0.0, meter - GameTuning.meterDrainPerSec * realDt);
      if (meter <= 0) chronoActive = false;
    } else {
      meter = min(1.0, meter + GameTuning.meterFillPerSec * realDt);
    }
  }

  void _updateTimeScale(double realDt) {
    final target = chronoActive ? GameTuning.slowFactor : 1.0;
    timeScale += (target - timeScale) * min(1.0, realDt * 14.0);

    // Star trails drain quickly when chrono engages so the recede
    // feels deliberate, but still soft — not a hard cut.
    final trailTarget = chronoActive ? 0.0 : 1.0;
    starTrailBlend +=
        (trailTarget - starTrailBlend) * min(1.0, realDt * 6.0);
  }

  // ---------------------- Obstacles ----------------------
  /// Difficulty curve in 0..1.6 as a function of forward distance.
  /// Pure; extracted as a static so tests can pin its shape without
  /// spinning up a full simulation.
  static double difficultyAt(double distance) =>
      min(1.6, distance / 12000.0);

  double _difficulty() => difficultyAt(distance);

  void _spawnObstacles() {
    // Keep spawning until there's enough runway ahead of the player.
    var guard = 0;
    while (nextObstacleAt < distance + viewH * 1.8 && guard++ < 20) {
      final wy = nextObstacleAt;
      _spawnOne(wy);
      final d = _difficulty();
      final spacing =
          _rand(340.0 - d * 90.0, 520.0 - d * 140.0).clamp(200.0, 560.0);
      nextObstacleAt = wy + spacing;
    }
  }

  void _spawnOne(double worldY) {
    final d = _difficulty();
    final minGap = 110.0 - d * 50.0;
    final maxGap = 190.0 - d * 60.0;
    final gap = max(70.0, _rand(minGap, maxGap));
    final usable = viewW - GameTuning.trackMargin * 2;

    // Type selection, following the draft's vocabulary unlock curve.
    final types = <_Kind>[
      _Kind.wall,
      _Kind.wall,
      _Kind.slab,
      if (d >= 0.35) _Kind.comb,
      _Kind.diag,
    ];
    // Very early on, only walls.
    final effective = d < 0.15 ? <_Kind>[_Kind.wall] : types;
    final kind = effective[rng.nextInt(effective.length)];

    final thickness = _rand(22.0, 36.0);
    final color = _randomObstacleColor();

    final m = GameTuning.trackMargin;
    switch (kind) {
      case _Kind.wall:
        final gapX = _rand(m + gap / 2, viewW - m - gap / 2);
        obstacles.add(Obstacle.wall(
          worldY: worldY,
          thickness: thickness,
          gapX: gapX,
          gap: gap,
          color: color,
        ));
        break;
      case _Kind.slab:
        // Two walls close together, offset gaps.
        final gx1 = _rand(
          m + gap / 2 + 40,
          viewW - m - gap / 2 - 40,
        );
        obstacles.add(Obstacle.wall(
          worldY: worldY,
          thickness: thickness,
          gapX: gx1,
          gap: gap,
          color: color,
        ));
        final gx2 = _rand(m + gap / 2, viewW - m - gap / 2);
        obstacles.add(Obstacle.wall(
          worldY: worldY + _rand(180.0, 260.0),
          thickness: thickness,
          gapX: gx2,
          gap: gap * 1.05,
          color: color,
        ));
        break;
      case _Kind.comb:
        final count = 3 + rng.nextInt(3); // 3..5
        final laneW = usable / count;
        final openIdx = rng.nextInt(count);
        for (var i = 0; i < count; i++) {
          if (i == openIdx) continue;
          final x = m + laneW * i + laneW / 2;
          obstacles.add(Obstacle.pillar(
            worldY: worldY,
            thickness: thickness,
            x: x,
            halfW: laneW / 2 - 14,
            color: color,
          ));
        }
        break;
      case _Kind.diag:
        final gx1 = _rand(m + gap / 2, viewW - m - gap / 2);
        final sign = rng.nextBool() ? -1.0 : 1.0;
        final raw = gx1 + sign * _rand(120.0, 220.0);
        final gx2 = raw.clamp(
          m + gap / 2,
          viewW - m - gap / 2,
        );
        obstacles.add(Obstacle.wall(
          worldY: worldY,
          thickness: thickness,
          gapX: gx1,
          gap: gap,
          color: color,
        ));
        obstacles.add(Obstacle.wall(
          worldY: worldY + _rand(140.0, 200.0),
          thickness: thickness,
          gapX: gx2,
          gap: gap * 0.95,
          color: color,
        ));
        break;
    }
  }

  Color _randomObstacleColor() {
    // Cyan-ish HSL range from the draft: hsl(200..240, 90%, 55..65%).
    // Converted to Dart via an HSL→RGB helper.
    final h = 200.0 + rng.nextDouble() * 40.0;
    final l = 0.55 + rng.nextDouble() * 0.10;
    return _hslColor(h, 0.90, l);
  }

  // ---------------------- Near-miss / culling ----------------------
  void _cullAndAwardNearMiss() {
    for (final o in obstacles) {
      if (!o.passed && o.worldY < distance - 10) {
        o.passed = true;
        final tier = _nearMissTier(o);
        if (tier > 0) {
          _awardNearMiss(tier, o);
        }
      }
    }
    // Remove anything well behind.
    obstacles.removeWhere((o) => o.worldY < distance - viewH);
  }

  int _nearMissTier(Obstacle o) {
    final px = playerX;
    if (o.shape == ObstacleShape.wall) {
      final gapL = o.gapX - o.gap / 2;
      final gapR = o.gapX + o.gap / 2;
      final closest = min((px - gapL).abs(), (px - gapR).abs());
      if (closest < GameTuning.nearMissTier3) return 3;
      if (closest < GameTuning.nearMissTier2) return 2;
      if (closest < GameTuning.nearMissTier1) return 1;
      return 0;
    } else {
      final closest =
          min((px - (o.x - o.halfW)).abs(), (px - (o.x + o.halfW)).abs());
      if (closest < GameTuning.pillarNearMissTier2) return 2;
      if (closest < GameTuning.pillarNearMissTier1) return 1;
      return 0;
    }
  }

  void _awardNearMiss(int tier, Obstacle o) {
    nearMisses += 1;
    final bonus = 40.0 * tier;
    score += bonus * streakMultiplier;

    streakSteps = min(GameTuning.maxStreakSteps, streakSteps + 1);
    streakMultiplier = 1.0 + streakSteps * GameTuning.streakPerMiss;
    _streakTimer = GameTuning.streakDecaySeconds;

    final refund = tier == 3
        ? GameTuning.meterRefundTier3
        : tier == 2
            ? GameTuning.meterRefundTier2
            : GameTuning.meterRefundTier1;
    final before = meter;
    meter = (meter + refund).clamp(0.0, 1.0);
    final applied = meter - before;
    if (applied > 0) {
      meterRefundAmount = applied;
      meterRefundTimer = GameTuning.meterRefundDisplaySeconds;
    }

    nearMissFlash = tier == 3 ? 'PERFECT' : 'NEAR MISS';
    _nearMissFlashTimer = 0.5;

    _burst(playerX, viewH - GameTuning.playerBase, tier);
  }

  void _decayStreak() {
    if (_streakTimer <= 0 || streakSteps == 0) return;
    _streakTimer -= 1 / 60; // approx; exact cadence isn't critical
    if (_streakTimer <= 0) {
      streakSteps = max(0, streakSteps - 1);
      streakMultiplier = 1.0 + streakSteps * GameTuning.streakPerMiss;
      if (streakSteps > 0) _streakTimer = 1.5;
    }
  }

  // ---------------------- Collisions ----------------------
  void _checkCollisions() {
    final py = viewH - GameTuning.playerBase;
    for (final o in obstacles) {
      final screenY = py - (o.worldY - distance);
      if (screenY < -60 || screenY > viewH + 60) continue;
      if (_hits(o, playerX, py, screenY)) {
        _crash();
        return;
      }
    }
  }

  bool _hits(Obstacle o, double px, double py, double screenY) {
    const r = GameTuning.playerRadius;
    final top = screenY - o.thickness / 2;
    final bot = screenY + o.thickness / 2;
    if (py + r < top || py - r > bot) return false;

    if (o.shape == ObstacleShape.wall) {
      final gapL = o.gapX - o.gap / 2;
      final gapR = o.gapX + o.gap / 2;
      if (px - r > gapL && px + r < gapR) return false;
      return true;
    } else {
      final left = o.x - o.halfW;
      final right = o.x + o.halfW;
      if (px + r < left || px - r > right) return false;
      return true;
    }
  }

  void _crash() {
    if (gameOver) return;
    gameOver = true;
    chronoActive = false;
    shake = 18.0;
    flashOpacity = 1.0;

    final cx = playerX;
    final cy = viewH - GameTuning.playerBase;
    for (var i = 0; i < 60; i++) {
      final ang = rng.nextDouble() * pi * 2;
      final sp = _rand(120.0, 520.0);
      final c = i % 3 == 0
          ? const Color(0xffff4d6d)
          : (i % 3 == 1 ? const Color(0xffffd166) : const Color(0xff7cf7ff));
      particles.add(Particle(
        x: cx,
        y: cy,
        vx: cos(ang) * sp,
        vy: sin(ang) * sp,
        life: _rand(0.5, 1.1),
        maxLife: 1.1,
        radius: _rand(1.5, 3.5),
        color: c,
      ));
    }

    if (score > highScore) highScore = score.floor();
  }

  void _burst(double x, double y, int intensity) {
    final n = 8 + intensity * 6;
    final color = intensity >= 3
        ? const Color(0xffffd166)
        : const Color(0xff7cf7ff);
    for (var i = 0; i < n; i++) {
      final ang = rng.nextDouble() * pi * 2;
      final sp = _rand(80.0, 260.0);
      particles.add(Particle(
        x: x,
        y: y,
        vx: cos(ang) * sp,
        vy: sin(ang) * sp - 60,
        life: _rand(0.35, 0.7),
        maxLife: 0.7,
        radius: _rand(1.5, 3.0),
        color: color,
      ));
    }
  }

  // ---------------------- Ambient ----------------------
  void _updateTrail() {
    trail.add(TrailSample(playerX, viewH - GameTuning.playerBase, chronoActive));
    if (trail.length > _maxTrail) trail.removeAt(0);
  }

  void _tickParticles(double realDt) {
    for (final p in particles) {
      p.x += p.vx * realDt;
      p.y += p.vy * realDt + (chronoActive ? 0 : 40 * realDt);
      p.life -= realDt;
    }
    particles.removeWhere((p) => p.life <= 0);
    if (particles.length > 400) {
      particles.removeRange(0, particles.length - 400);
    }
  }

  void _tickStars(double realDt) {
    // Stars drift slowly on their own; the painter scrolls them by
    // [distance] so slow-mo (via timeScale) naturally slows the field.
    for (final s in stars) {
      s.y += (realDt * timeScale) * (0.015 * (0.2 + s.z));
      if (s.y > 1.0) {
        s.y -= 1.0;
        s.x = rng.nextDouble();
        s.z = 0.2 + rng.nextDouble() * 0.8;
      }
    }
  }

  // ---------------------- Helpers ----------------------
  double _rand(double a, double b) => a + rng.nextDouble() * (b - a);

  /// Minimal HSL→RGB for obstacle colors.
  Color _hslColor(double h, double s, double l) {
    h = h % 360;
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;
    double r = 0, g = 0, b = 0;
    if (h < 60) {
      r = c; g = x; b = 0;
    } else if (h < 120) {
      r = x; g = c; b = 0;
    } else if (h < 180) {
      r = 0; g = c; b = x;
    } else if (h < 240) {
      r = 0; g = x; b = c;
    } else if (h < 300) {
      r = x; g = 0; b = c;
    } else {
      r = c; g = 0; b = x;
    }
    return Color.fromARGB(
      255,
      ((r + m) * 255).round().clamp(0, 255),
      ((g + m) * 255).round().clamp(0, 255),
      ((b + m) * 255).round().clamp(0, 255),
    );
  }
}

enum _Kind { wall, slab, comb, diag }

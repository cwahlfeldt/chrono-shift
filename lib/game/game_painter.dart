import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../style/palette.dart';
import 'game_state.dart';
import 'game_tuning.dart';
import 'models.dart';

/// 2D top-down painter for Chrono-Swipe. Mirrors the draft's look:
/// radial backdrop, parallax starfield, track edge lines, scrolling
/// center stripe, flat wall/pillar obstacles with neon glow, polyline
/// trail behind the player, and a pulsing player orb.
class GamePainter extends CustomPainter {
  final GameState state;
  final Palette palette;

  GamePainter({required this.state, required this.palette})
    : super(repaint: state);

  final Random _shakeRng = Random();

  @override
  void paint(Canvas canvas, Size size) {
    // Keep GameState's concept of the viewport in sync with the actual
    // paint size — spawn logic, collisions, and UI positioning all use it.
    state.setViewport(size);

    canvas.save();

    if (state.shake > 0.01) {
      canvas.translate(
        (_shakeRng.nextDouble() - 0.5) * state.shake,
        (_shakeRng.nextDouble() - 0.5) * state.shake,
      );
    }

    _paintBackground(canvas, size);
    _paintStars(canvas, size);
    // _paintTrackEdges(canvas, size);
    // _paintCenterStripe(canvas, size);
    _paintObstacles(canvas, size);
    _paintTrail(canvas, size);
    _paintPlayer(canvas, size);
    _paintParticles(canvas, size);

    canvas.restore();

    // Chrono tint.
    if (state.timeScale < 0.95) {
      final k = (1.0 - state.timeScale) / (1.0 - GameTuning.slowFactor);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = palette.cyan.withValues(alpha: 0.07 * k.clamp(0.0, 1.0)),
      );
    }

    if (state.flashOpacity > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: state.flashOpacity),
      );
    }

    if (state.nearMissFlash != null) _paintNearMissText(canvas, size);
  }

  // ---------- Backdrop ----------

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.3),
      size.width * 0.9,
      [const Color(0xff0a1430), const Color(0xff05060a)],
      [0.0, 0.85],
    );
    canvas.drawRect(rect, Paint()..shader = gradient);
  }

  void _paintStars(Canvas canvas, Size size) {
    final active = state.chronoActive;
    final color = active ? const Color(0xffa9f4ff) : const Color(0xffcfd8ff);
    for (final s in state.stars) {
      final sx = s.x * size.width;
      // Scroll stars by distance * z so nearer (high-z) stars move faster.
      var sy = (s.y * size.height + state.distance * 0.2 * s.z) % size.height;
      if (sy < 0) sy += size.height;
      final r = s.z * 2.0;
      canvas.drawRect(
        Rect.fromLTWH(sx, sy, r, r),
        Paint()..color = color.withValues(alpha: 0.3 + 0.6 * s.z),
      );
    }
  }

  // ---------- Track ----------

  void _paintTrackEdges(Canvas canvas, Size size) {
    final m = GameTuning.trackMargin;
    final p = Paint()
      ..color = palette.cyan.withValues(alpha: 0.28)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(m, 0), Offset(m, size.height), p);
    canvas.drawLine(
      Offset(size.width - m, 0),
      Offset(size.width - m, size.height),
      p,
    );
  }

  void _paintCenterStripe(Canvas canvas, Size size) {
    const spacing = 80.0;
    const dashLen = 30.0;
    final offset = state.distance % spacing;
    final paint = Paint()
      ..color = state.chronoActive
          ? palette.cyan.withValues(alpha: 0.3)
          : palette.cyan.withValues(alpha: 0.14)
      ..strokeWidth = 2;
    for (var y = -spacing + offset; y < size.height + spacing; y += spacing) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashLen),
        paint,
      );
    }
  }

  // ---------- Obstacles ----------

  void _paintObstacles(Canvas canvas, Size size) {
    final py = size.height - GameTuning.playerBase;
    for (final o in state.obstacles) {
      final screenY = py - (o.worldY - state.distance);
      if (screenY < -80 || screenY > size.height + 80) continue;
      if (o.shape == ObstacleShape.wall) {
        _paintWall(canvas, size, o, screenY);
      } else {
        _paintPillar(canvas, o, screenY);
      }
    }
  }

  void _paintWall(Canvas canvas, Size size, Obstacle o, double y) {
    final gapL = o.gapX - o.gap / 2;
    final gapR = o.gapX + o.gap / 2;
    final th = o.thickness;

    // Glow body. Using a layered draw (blur + crisp) gets the neon look
    // without relying on canvas shadow filters that cost a lot on web.
    final glowR = Rect.fromLTWH(0, y - th / 2, gapL, th);
    final glowR2 = Rect.fromLTWH(gapR, y - th / 2, size.width - gapR, th);

    final blur = Paint()
      ..color = o.color.withValues(alpha: state.chronoActive ? 0.75 : 0.55)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        state.chronoActive ? 12 : 6,
      );
    canvas.drawRect(glowR, blur);
    canvas.drawRect(glowR2, blur);

    final solid = Paint()..color = o.color;
    canvas.drawRect(glowR, solid);
    canvas.drawRect(glowR2, solid);

    // Gap edge guides.
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(gapL, y - th / 2 - 6),
      Offset(gapL, y + th / 2 + 6),
      edge,
    );
    canvas.drawLine(
      Offset(gapR, y - th / 2 - 6),
      Offset(gapR, y + th / 2 + 6),
      edge,
    );
  }

  void _paintPillar(Canvas canvas, Obstacle o, double y) {
    final th = o.thickness;
    final rect = Rect.fromLTWH(o.x - o.halfW, y - th / 2, o.halfW * 2, th);

    final blur = Paint()
      ..color = o.color.withValues(alpha: state.chronoActive ? 0.7 : 0.5)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        state.chronoActive ? 11 : 5,
      );
    canvas.drawRect(rect, blur);

    canvas.drawRect(rect, Paint()..color = o.color);
  }

  // ---------- Trail ----------

  void _paintTrail(Canvas canvas, Size size) {
    if (state.trail.length < 2) return;
    for (var i = 1; i < state.trail.length; i++) {
      final a = state.trail[i - 1];
      final b = state.trail[i];
      final k = i / state.trail.length;
      final color = b.chrono
          ? palette.cyan.withValues(alpha: 0.08 + k * 0.55)
          : palette.gold.withValues(alpha: 0.05 + k * 0.45);
      final width = 2.0 + k * 6.0;
      canvas.drawLine(
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        Paint()
          ..color = color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = width,
      );
    }
  }

  // ---------- Player ----------

  void _paintPlayer(Canvas canvas, Size size) {
    if (state.gameOver) return;
    final x = state.playerX;
    final y = size.height - GameTuning.playerBase;
    final active = state.chronoActive;
    final ringColor = active ? palette.cyan : palette.gold;
    final core = active ? const Color(0xffa9f4ff) : const Color(0xfffff6c9);

    // Halo.
    canvas.drawCircle(
      Offset(x, y),
      18,
      Paint()
        ..color = ringColor.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, active ? 22 : 14),
    );

    // Pulsing outer ring.
    final pulse = 12 + sin(state.realTime * 18) * 2;
    canvas.drawCircle(
      Offset(x, y),
      pulse,
      Paint()
        ..color = ringColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Core.
    canvas.drawCircle(Offset(x, y), 8, Paint()..color = core);
  }

  // ---------- Particles ----------

  void _paintParticles(Canvas canvas, Size size) {
    for (final p in state.particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.radius,
        Paint()..color = p.color.withValues(alpha: a),
      );
    }
  }

  // ---------- Text ----------

  void _paintNearMissText(Canvas canvas, Size size) {
    final t = state.nearMissFlash ?? '';
    if (t.isEmpty) return;
    final isPerfect = t == 'PERFECT';
    final color = isPerfect ? palette.gold : palette.cyan;
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontFamily: 'Krona One',
          fontSize: 24,
          color: color,
          letterSpacing: 3,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.8), blurRadius: 14),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.42));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

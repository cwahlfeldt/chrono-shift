import 'dart:math';
import 'dart:ui' show Color;

/// A single obstacle on the track. Positions are in pixel/world units,
/// matching the draft's layout.
///
/// - [worldY] is the obstacle's forward position. The player's world-Y
///   equals [distance]; obstacles with worldY > distance are ahead.
/// - For walls: [gapX] and [gap] describe the horizontal gap; [thickness]
///   is the vertical band.
/// - For pillars: [x] and [halfW] are the pillar bounds.
class Obstacle {
  final ObstacleShape shape;
  final double worldY;
  final double thickness;
  // Wall-only:
  final double gapX;
  final double gap;
  // Pillar-only:
  final double x;
  final double halfW;
  final Color color;
  bool passed = false;
  bool nearMissAwarded = false;

  Obstacle.wall({
    required this.worldY,
    required this.thickness,
    required this.gapX,
    required this.gap,
    required this.color,
  })  : shape = ObstacleShape.wall,
        x = 0,
        halfW = 0;

  Obstacle.pillar({
    required this.worldY,
    required this.thickness,
    required this.x,
    required this.halfW,
    required this.color,
  })  : shape = ObstacleShape.pillar,
        gapX = 0,
        gap = 0;
}

enum ObstacleShape { wall, pillar }

/// A short-lived particle used for near-miss puffs and the crash burst.
class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double maxLife;
  double radius;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.radius,
    required this.color,
  });
}

/// Single star in the parallax backdrop. x/y are normalized (0..1).
class Star {
  double x;
  double y;
  double z; // 0.2..1.0 depth
  Star(this.x, this.y, this.z);
}

/// A sample of the player's path for the polyline trail.
class TrailSample {
  final double x;
  final double y;
  final bool chrono;
  const TrailSample(this.x, this.y, this.chrono);
}

final Random rng = Random();

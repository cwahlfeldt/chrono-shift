/// Single home for every feel-knob in Chrono-Swipe. Having them here
/// (rather than scattered across [GameState]) makes it trivial to A/B a
/// different feel by swapping this file — simulation code only reads,
/// never owns, the numbers.
///
/// Categories, in order: layout, speed, chrono meter, steering, streak,
/// near-miss thresholds, meter refund, scoring, HUD display.
class GameTuning {
  GameTuning._();

  // ---------- Layout ----------

  /// Distance from the bottom of the viewport where the player sits.
  static const double playerBase = 120.0;

  /// Inset from the left/right screen edges — the "track margin".
  static const double trackMargin = 28.0;

  /// Player collider radius (pixels).
  static const double playerRadius = 10.0;

  // ---------- Speed ----------

  /// Forward speed in px/sec at time-scale 1.
  static const double baseSpeed = 520.0;

  /// Additional px/s per px travelled, capped by [speedDistBoostCap].
  static const double speedDistBoost = 0.02;

  /// Maximum bonus forward speed from the distance ramp.
  static const double speedDistBoostCap = 380.0;

  // ---------- Chrono meter ----------

  /// Time-scale during Chrono-Shift. The sim multiplies dt by this.
  static const double slowFactor = 0.2;

  /// Meter consumption rate while Chrono-Shift is active (per real-sec).
  static const double meterDrainPerSec = 0.55;

  /// Meter refill rate when not chrono-shifting (per real-sec).
  static const double meterFillPerSec = 0.32;

  // ---------- Steering ----------

  /// Steering lerp factor applied with real-time dt (normal play).
  static const double steerFollow = 14.0;

  /// Steering lerp factor during Chrono-Shift — higher, so steering
  /// stays crisp even when the world is slow.
  static const double steerFollowChrono = 18.0;

  /// Keyboard nudge acceleration in px/sec.
  static const double keyboardSteer = 1800.0;

  /// Pointer must be held this long before Chrono-Shift engages —
  /// distinguishes a "hold" from a "drag to steer".
  static const double chronoHoldSeconds = 0.05;

  // ---------- Streak ----------

  /// Multiplier added per near-miss step.
  static const double streakPerMiss = 0.15;

  /// Seconds before a streak step decays.
  static const double streakDecaySeconds = 2.5;

  /// Maximum number of streak steps — caps the multiplier.
  static const int maxStreakSteps = 9; // 1 + 9*0.15 = 2.35x

  // ---------- Near-miss thresholds (wall) ----------

  static const double nearMissTier3 = 16.0;
  static const double nearMissTier2 = 28.0;
  static const double nearMissTier1 = 44.0;

  // ---------- Near-miss thresholds (pillar) ----------

  static const double pillarNearMissTier2 = 14.0;
  static const double pillarNearMissTier1 = 26.0;

  // ---------- Meter refund per tier ----------

  /// Fraction of the 0..1 meter bar returned per tier. Tight shaves
  /// give back enough slow-mo to make aggressive play self-sustaining.
  static const double meterRefundTier3 = 0.18;
  static const double meterRefundTier2 = 0.10;
  static const double meterRefundTier1 = 0.05;

  // ---------- Scoring ----------

  /// Score per forward px at the baseline multiplier.
  static const double scorePerPx = 0.1;

  /// In-tick multiplier applied to score while chrono-shifting.
  static const double chronoScoreScale = 2.2;

  // ---------- HUD ----------

  /// How long the transient "+N%" chrono-refund indicator stays on the
  /// HUD before fading.
  static const double meterRefundDisplaySeconds = 0.9;

  // ---------- Intro ----------

  /// When true, PlayScreen runs a slide-up + 3-2-1 countdown before
  /// the game begins. Turn off to jump straight into a run for faster
  /// iteration on gameplay.
  static const bool introEnabled = true;

  /// Seconds the player takes to slide from off-screen-bottom to its
  /// resting [GameTuning.playerBase].
  static const double introSlideSeconds = 0.45;

  /// Seconds per countdown tick. 3 ticks → total intro tail.
  static const double introCountdownTickSeconds = 0.7;
}

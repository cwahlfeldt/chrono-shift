import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../audio/audio_controller.dart';
import '../audio/sounds.dart';
import '../style/palette.dart';
import 'game_painter.dart';
import 'game_state.dart';
import 'high_score_store.dart';

/// The entire play session: input handling, game-loop driver, HUD overlay,
/// and game-over card.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  late final GameState _state;
  late final Ticker _ticker;
  final HighScoreStore _store = HighScoreStore();
  Duration _lastTick = Duration.zero;
  bool _scoreSaved = false;

  // Haptics edge-detection. We fire on transitions, not on every frame.
  bool _prevChronoActive = false;
  int _prevNearMisses = 0;
  bool _prevGameOver = false;

  // Input tracking.
  int? _activePointer;
  double _pointerHoldSeconds = 0.0;
  // How long a pointer must be held (with little vertical motion) before
  // Chrono-Shift engages. Matches the draft's ~50ms guard.
  static const double _chronoHoldSeconds = 0.05;

  // Keyboard.
  final Set<LogicalKeyboardKey> _keysDown = {};
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _state = GameState();
    _ticker = createTicker(_onTick);
    _boot();
  }

  Future<void> _boot() async {
    _state.highScore = await _store.load();
    _state.reset();
    _lastTick = Duration.zero;
    _ticker.start();
    _focus.requestFocus();
    if (mounted) setState(() {});
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final rawDt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final dt = rawDt.clamp(0.0, 1 / 24);

    // Keyboard nudge for steering (fallback for desktop).
    if (!_state.gameOver) {
      if (_keysDown.contains(LogicalKeyboardKey.arrowLeft) ||
          _keysDown.contains(LogicalKeyboardKey.keyA)) {
        _state.nudgeSteer(-1.0, dt);
      }
      if (_keysDown.contains(LogicalKeyboardKey.arrowRight) ||
          _keysDown.contains(LogicalKeyboardKey.keyD)) {
        _state.nudgeSteer(1.0, dt);
      }
    }

    // Hold-for-chrono: if a pointer is down and has been held for at least
    // _chronoHoldSeconds, activate. Taps/swipes that lift early never fire.
    if (_activePointer != null) {
      _pointerHoldSeconds += dt;
      if (_pointerHoldSeconds > _chronoHoldSeconds && _state.meter > 0.02) {
        _state.setChronoActive(true);
      }
    }

    _state.tick(dt);

    _fireHaptics();

    if (_state.gameOver && !_scoreSaved) {
      _scoreSaved = true;
      _store.save(_state.highScore);
      try {
        context.read<AudioController>().playSfx(SfxType.wssh);
      } catch (_) {}
    }
  }

  void _fireHaptics() {
    // Chrono engage / disengage — a light tick on each edge so the player
    // feels the world shift even before they see it.
    if (_state.chronoActive != _prevChronoActive) {
      HapticFeedback.selectionClick();
      _prevChronoActive = _state.chronoActive;
    }

    // Near-miss. `nearMisses` increments once per award; the flash text
    // carries the tier (PERFECT = tier 3, NEAR MISS = tier 1 or 2).
    if (_state.nearMisses != _prevNearMisses) {
      if (_state.nearMissFlash == 'PERFECT') {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      _prevNearMisses = _state.nearMisses;
    }

    // Crash.
    if (_state.gameOver && !_prevGameOver) {
      HapticFeedback.heavyImpact();
      _prevGameOver = true;
    } else if (!_state.gameOver && _prevGameOver) {
      // Reset on retry so the next crash fires again.
      _prevGameOver = false;
    }
  }

  void _restart() {
    _scoreSaved = false;
    _state.reset();
    _activePointer = null;
    _pointerHoldSeconds = 0.0;
    _prevChronoActive = false;
    _prevNearMisses = 0;
    _prevGameOver = false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    _state.dispose();
    super.dispose();
  }

  // ---------------- Input ----------------

  void _onPointerDown(PointerDownEvent e, Size size) {
    if (_state.gameOver) return;
    _activePointer = e.pointer;
    _pointerHoldSeconds = 0.0;
  }

  void _onPointerMove(PointerMoveEvent e, Size size) {
    if (e.pointer != _activePointer || _state.gameOver) return;
    // Direct-drag: the finger's horizontal delta maps 1:1 to target-x.
    _state.addSteerDelta(e.delta.dx);
  }

  void _onPointerUp(PointerEvent e) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    _pointerHoldSeconds = 0.0;
    _state.setChronoActive(false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent) {
      _keysDown.add(e.logicalKey);
      if (e.logicalKey == LogicalKeyboardKey.space ||
          e.logicalKey == LogicalKeyboardKey.shiftLeft ||
          e.logicalKey == LogicalKeyboardKey.shiftRight) {
        _state.setChronoActive(true);
        return KeyEventResult.handled;
      }
      if (e.logicalKey == LogicalKeyboardKey.enter && _state.gameOver) {
        _restart();
        return KeyEventResult.handled;
      }
    } else if (e is KeyUpEvent) {
      _keysDown.remove(e.logicalKey);
      if (e.logicalKey == LogicalKeyboardKey.space ||
          e.logicalKey == LogicalKeyboardKey.shiftLeft ||
          e.logicalKey == LogicalKeyboardKey.shiftRight) {
        _state.setChronoActive(false);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();
    return Scaffold(
      backgroundColor: palette.background,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _onPointerDown(e, size),
                    onPointerMove: (e) => _onPointerMove(e, size),
                    onPointerUp: _onPointerUp,
                    onPointerCancel: _onPointerUp,
                    child: CustomPaint(
                      painter: GamePainter(state: _state, palette: palette),
                      size: Size.infinite,
                    ),
                  ),
                  _Hud(state: _state, palette: palette),
                  AnimatedBuilder(
                    animation: _state,
                    builder: (context, _) {
                      if (!_state.gameOver) return const SizedBox.shrink();
                      return _GameOverCard(
                        state: _state,
                        palette: palette,
                        onRestart: _restart,
                        onHome: () => context.go('/'),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------- HUD ----------------

class _Hud extends StatelessWidget {
  final GameState state;
  final Palette palette;

  const _Hud({required this.state, required this.palette});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pill(
                      'SCORE',
                      '${state.score.floor()}',
                      palette.cyan,
                      palette,
                    ),
                    _pill('BEST', '${state.highScore}', palette.gold, palette),
                    _pill(
                      'CHRONO',
                      '${(state.meter * 100).round()}%',
                      state.chronoActive ? palette.cyan : palette.white,
                      palette,
                    ),
                  ],
                ),
                const Spacer(),
                if (state.streakMultiplier > 1.01)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'x${state.streakMultiplier.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: palette.gold,
                          fontFamily: 'Krona One',
                          fontSize: 22,
                          shadows: [
                            Shadow(
                              color: palette.gold.withValues(alpha: 0.6),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                _ChronoBar(state: state, palette: palette),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    state.chronoActive
                        ? 'CHRONO-SHIFT'
                        : 'DRAG to steer  ·  HOLD to slow time',
                    style: TextStyle(
                      color: state.chronoActive ? palette.cyan : palette.dim,
                      letterSpacing: 1.4,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _pill(String label, String value, Color valueColor, Palette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xcc0a1230),
        border: Border.all(
          color: palette.cyan.withValues(alpha: 0.22),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.dim,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChronoBar extends StatelessWidget {
  final GameState state;
  final Palette palette;
  const _ChronoBar({required this.state, required this.palette});

  @override
  Widget build(BuildContext context) {
    final pct = state.meter.clamp(0.0, 1.0);
    final active = state.chronoActive;
    final color = active
        ? palette.cyan
        : (state.meter > 0.3 ? palette.white : palette.red);
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: pct,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: active ? 0.8 : 0.3),
                blurRadius: active ? 14 : 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Game Over ----------------

class _GameOverCard extends StatelessWidget {
  final GameState state;
  final Palette palette;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  const _GameOverCard({
    required this.state,
    required this.palette,
    required this.onRestart,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final scoreInt = state.score.floor();
    final isNewBest = scoreInt >= state.highScore && scoreInt > 0;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xcc0a1230),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cyan.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: palette.cyan.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isNewBest ? 'NEW PERSONAL BEST' : 'CRASHED',
                style: TextStyle(
                  fontFamily: 'Krona One',
                  fontSize: isNewBest ? 22 : 26,
                  color: isNewBest ? palette.gold : palette.red,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$scoreInt',
                style: TextStyle(
                  fontFamily: 'Krona One',
                  fontSize: 68,
                  height: 1.0,
                  color: palette.gold,
                  shadows: [
                    Shadow(
                      color: palette.gold.withValues(alpha: 0.7),
                      blurRadius: 22,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'BEST  ${state.highScore}',
                style: TextStyle(
                  color: palette.dim,
                  fontSize: 13,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${state.nearMisses} near-misses',
                style: TextStyle(color: palette.dim, fontSize: 12),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ghostButton('HOME', palette, onHome),
                  const SizedBox(width: 12),
                  _primaryButton('RETRY', palette, onRestart),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, Palette palette, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
          color: palette.cyan,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: palette.cyan.withValues(alpha: 0.5),
              blurRadius: 20,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xff021018),
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _ghostButton(String label, Palette palette, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: palette.dim),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: palette.dim,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}

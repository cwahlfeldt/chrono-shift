import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../style/palette.dart';
import 'game_painter.dart';
import 'game_state.dart';

/// Lightweight backdrop used behind the main menu. Runs a [GameState] in
/// idle mode so the starfield and center stripe keep drifting, but no
/// obstacles or gameplay happen.
class IdleBackdrop extends StatefulWidget {
  const IdleBackdrop({super.key});

  @override
  State<IdleBackdrop> createState() => _IdleBackdropState();
}

class _IdleBackdropState extends State<IdleBackdrop>
    with SingleTickerProviderStateMixin {
  late final GameState _state;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _state = GameState();
    // Seed stars without kicking off a real run.
    _state.reset();
    _state.running = false;
    _state.gameOver = false;
    _state.obstacles.clear();
    _state.trail.clear();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_last == Duration.zero) {
      _last = elapsed;
      return;
    }
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 24);
    _last = elapsed;
    _state.idleTick(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();
    return CustomPaint(
      painter: GamePainter(state: _state, palette: palette),
      size: Size.infinite,
    );
  }
}

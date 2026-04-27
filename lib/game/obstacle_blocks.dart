/// Authored obstacle "blocks" — multi-row patterns that the spawner picks
/// from based on current difficulty. Each block stacks rows at a fixed
/// `cellHeight` in world pixels; lanes are a logical integer count
/// mapped to viewport width at emit time.
library;

sealed class BlockRow {
  const BlockRow();
}

/// A row of wall-cells at the listed lane indices. Other lanes are open
/// (a "gap" is just any lane index you leave out).
///
/// Adjacent filled lanes render as a continuous bar; a single filled
/// lane reads like a pillar. Stack rows to design walls cell-by-cell.
class Row extends BlockRow {
  final List<int> lanes;
  const Row(this.lanes);
}

/// Empty spacer row — advances the row cursor without emitting cells.
class GapRow extends BlockRow {
  const GapRow();
}

class ObstacleBlock {
  final String name;

  /// 0..1.6, matching `GameState.difficultyAt(distance)`.
  final double difficulty;

  /// Logical lane count. 12 is the default; divisible by 2/3/4/6 so
  /// coarse "6-column" patterns and fine single-lane patterns both fit.
  final int lanes;

  final List<BlockRow> rows;

  /// Vertical thickness (world pixels) of one [Row] cell. Consecutive
  /// rows are placed touching, so this is also the vertical "cell size"
  /// of the design grid.
  final double cellHeight;

  /// World-pixel breather inserted by a [GapRow]. Independent of cell
  /// height so designers can stack tight walls and still get a sensible
  /// breathing-room gap when they want one.
  final double rowSpacing;

  const ObstacleBlock({
    required this.name,
    required this.difficulty,
    required this.rows,
    this.lanes = 12,
    this.cellHeight = 28.0,
    this.rowSpacing = 90.0,
  });
}

// 12-lane grid:  0  1  2  3  4  5  6  7  8  9 10 11
//
// Visual key in comments:  #  = filled cell      .  = open

const ObstacleBlock kEasyWall = ObstacleBlock(
  name: 'easy_wall',
  difficulty: 0.1,
  rows: [
    // # # # # . . . . # # # #   — gap at lanes 4..7
    Row([0, 2, 5, 11]),
  ],
);

const ObstacleBlock kEasyWall2 = ObstacleBlock(
  name: 'easy_wall_2',
  difficulty: 0.2,
  rows: [
    // # # # # # # # . . . # #   — gap right
    Row([0, 1, 2, 3, 4, 5, 6, 10, 11]),
    GapRow(),
    GapRow(),

    // # # . . . # # # # # # #   — gap left
    Row([0, 1, 5, 6, 7, 8, 9, 10, 11]),
  ],
);

const ObstacleBlock kMidComb = ObstacleBlock(
  name: 'mid_comb',
  difficulty: 0.5,
  rows: [
    // # # # # # . . # # # # #
    Row([0, 1, 3, 7, 9, 10, 11]),
    GapRow(),
    GapRow(),

    // # # # # # # # # # . . #
    Row([1, 11]),

    GapRow(),
    GapRow(),

    // Wide centered gap to recover.
    // # # # # . . . . # # # #
    Row([0, 1, 2, 3, 8, 9, 10, 11]),
  ],
);

const ObstacleBlock kHardSlalom = ObstacleBlock(
  name: 'hard_slalom',
  difficulty: 1.0,
  rows: [
    // Tight gap at lane 3.
    // # # # . # # # # # # # #
    Row([0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11]),
    GapRow(),
    // Tight gap at lane 9 — slalom across.
    // # # # # # # # # # . # #
    Row([0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11]),
    GapRow(),
    // Single-lane gap at 6.
    // # # # # # # . # # # # #
    Row([0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11]),
    // Single-lane gap at 7 (right above) — forces a quick step.
    // # # # # # # # . # # # #
    Row([0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11]),
  ],
);

const List<ObstacleBlock> kBlockLibrary = [
  kEasyWall,
  kEasyWall2,
  kMidComb,
  kHardSlalom,
];

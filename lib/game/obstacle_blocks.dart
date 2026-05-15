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
    this.lanes = 13,
    this.cellHeight = 28.0,
    this.rowSpacing = 90.0,
  });
}

// 12-lane grid:  0  1  2  3  4  5  6  7  8  9 10 11
//
// Visual key in comments:  #  = filled cell      .  = open
const Row wall = Row([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
const Row center = Row([0, 1, 2, 3, 4, 8, 9, 10, 11, 12]);
const Row left = Row([0, 1, 2, 3, 4, 5, 6, 10, 11, 12]);
const Row right = Row([0, 1, 5, 6, 7, 8, 9, 10, 11, 12]);

const ObstacleBlock centerGap = ObstacleBlock(
  name: 'easy_wall',
  difficulty: 0.1,
  rows: [center],
);

const ObstacleBlock rightGap = ObstacleBlock(
  name: 'easy_wall_right',
  difficulty: 0.1,
  rows: [right],
);

const ObstacleBlock leftGap = ObstacleBlock(
  name: 'easy_wall_left',
  difficulty: 0.1,
  rows: [left],
);

const ObstacleBlock checkered = ObstacleBlock(
  name: 'checkered',
  difficulty: 0.2,
  rows: [
    Row([2, 3, 6, 7, 10, 11, 12]),
  ],
);

const ObstacleBlock crisscross = ObstacleBlock(
  name: 'checkered',
  difficulty: 0.2,
  rows: [
    Row([0, 1, 2, 3, 4, 5, 6, 0, 0, 0, 0, 11, 12]),
    GapRow(),
    Row([0, 1, 0, 0, 0, 5, 6, 7, 8, 9, 10, 11, 12]),
  ],
);

const ObstacleBlock narrowing = ObstacleBlock(
  name: 'narrowing',
  difficulty: 0.2,
  rows: [
    Row([0, 1, 2, 3, 4, 0, 0, 0, 8, 9, 10, 11, 12]),
    GapRow(),
    Row([0, 1, 2, 3, 0, 0, 0, 0, 0, 9, 10, 11, 12]),
    GapRow(),
    Row([0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 10, 11, 12]),
    GapRow(),
    Row([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11, 12]),
    GapRow(),
    Row([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12]),
    GapRow(),
    Row([6]),
    GapRow(),
    Row([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12]),
    GapRow(),
    Row([0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11, 12]),
    GapRow(),
    Row([0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 10, 11, 12]),
    GapRow(),
    Row([0, 1, 2, 3, 0, 0, 0, 0, 0, 9, 10, 11, 12]),
    GapRow(),
    Row([0, 1, 2, 3, 4, 0, 0, 0, 8, 9, 10, 11, 12]),
  ],
);

const List<ObstacleBlock> kBlockLibrary = [
  centerGap,
  leftGap,
  rightGap,
  narrowing,
  checkered,
];

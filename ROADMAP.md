# Chrono-Swipe — Roadmap

Companion to [GAME.md](GAME.md). That document defines what the game *is*; this one explores what it could become. Entries are opinionated and ordered within each section — earlier ideas are higher-leverage or lower-risk, later ones are more speculative or easier to get wrong.

The core design tension from GAME.md — *the thing that saves you is also the thing that scores you* — is the yardstick. An idea that sharpens that tension is worth pursuing; an idea that muddies it probably isn't, no matter how cool it sounds in isolation.

---

## 1. Gameplay & Mechanics

### Worth doing

- **Chrono-Burst (tap-to-flick).** A short tap consumes a fixed meter chunk for a very brief (~150ms) slow-motion *pulse*. Rewards players who can read one obstacle at a time instead of hoarding the hold. Extends the vocabulary of the single button without adding a second one.
- **Perfect-entry bonus on Chrono-Shift.** If you activate slow-mo *within a frame or two* of entering an obstacle's near-miss window, award a flat bonus and a brief meter refund. This rewards *timing* the shift rather than just holding it preemptively, which is the move that currently dominates.
- **Obstacle: moving gap.** A wall whose gap slides left/right as it approaches. Forces use of slow-mo specifically for *tracking*, not just narrow threading. Strictly additive to the existing vocabulary.
- **Obstacle: shrinking gap.** A wall whose gap narrows as it gets closer. Encourages committing to a lane early and punishes late indecision — a different reaction type than the current mix.
- **Near-miss feedback tiers in the HUD.** Today the flash just says `NEAR MISS` or `PERFECT`. Show the pixel distance briefly (e.g. `2px`) — it sharpens the dopamine loop and makes skill growth legible.

### Worth considering

- **Second input: a swap / dodge.** A two-finger tap that instantly teleports the craft to the mirrored x-position. Expands expression, but risks breaking the one-finger fantasy. Prototype behind a feature flag before committing.
- **Corridor variants.** Short stretches where the track narrows or widens, adding macro-scale terrain. Works only if the change is *telegraphed* well enough that slow-mo isn't the only counterplay.
- **Run modifiers (seeded).** Optional daily seed with a twist — e.g. "walls only", "meter drains 2x", "no streak decay". Gives replay variety without fragmenting the core mode.

### Be careful with

- **Lives / continues.** Would directly undermine the "one more run" loop. If added, it should cost the best-score claim (non-canonical run).
- **Enemies that shoot back.** A different genre. Don't.
- **Upgrade trees between runs.** Turns the skill curve into a progression curve, which flattens the thing that makes the game work.

---

## 2. Feel & Polish

### Worth doing

- **Haptics on near-miss and chrono engage/disengage.** iOS `HapticFeedback.lightImpact` is one line. Perfect near-miss deserves a slightly heavier thump. This is the single highest feel-per-effort change available.
- **Audio reactivity to Chrono-Shift.** Low-pass filter on music, pitch-shift SFX down ~2 semitones during slow-mo. The `audioplayers` package can't do this directly; consider `just_audio` or a fixed pre-rendered slow-mo music stem. Even a crude ducking/volume swap would sell the effect.
- **Speed lines / vignette at high speed.** After some distance threshold, faint radial motion-blur streaks from the edges inward. Cheap in `CustomPainter` (a handful of alpha-gradient lines), huge for the "too fast to react" fantasy.
- **Streak HUD: visible decay timer.** The streak multiplier already decays on a timer; expose it as a thin shrinking bar under the `x1.45` chip so players can *play around* the decay instead of being surprised by it.
- **Chromatic aberration on crash.** One-frame RGB channel offset at crash impact, decaying over ~200ms. Classic arcade juice, cheap to implement with three slightly-offset canvas layers or a simple shader.

### Worth considering

- **Custom crash camera.** Brief zoom-in on impact point before the game-over card. Tricky to get right without feeling laggy — crashes need to feel snappy so the player can retry.
- **Palette variants per distance band.** Subtly shift the dominant hue as the run progresses (cyan → magenta → red-shift near the ragged edge of difficulty). Visualizes the difficulty curve without UI.
- **Particle trail on perfect-tier only.** Makes `PERFECT` near-misses visually distinct from ordinary ones at a glance.

### Be careful with

- **Full-screen shaders (bloom, CRT).** Tempting, expensive on mobile web, and they can muddy the minimalist aesthetic GAME.md is explicit about.
- **Background music that competes with SFX.** Current track is unobtrusive — keep it that way.

---

## 3. Meta & Retention

### Worth doing

- **Daily seed run.** One deterministic seed per calendar day, everyone plays the same track. Single-player leaderboard optional — even without a backend, a "your best today: X" stat gives structure to a session.
- **Personal history.** Store the last ~20 run scores locally, draw a sparkline on the game-over card. Cheap (`shared_preferences` already in the deps), strong retention hook.
- **Milestone callouts.** `FIRST 10,000!`, `100 RUNS!`, `500 NEAR-MISSES!` — local, unlockable, no server. Persists meaning across sessions when the only other metric is high score.

### Worth considering

- **Ghost of best run.** A faint trail rendering where *past-you* was at the same distance on your best run. Requires recording player-x at distance intervals during a run (small, compressible). Powerful motivator. The painter already has a trail renderer that could be adapted.
- **Global leaderboard.** Real retention lever, but adds a backend, auth, anti-cheat, moderation. Out of scope until the game finds an audience.
- **Cosmetic unlocks tied to distance.** Different player orb colors, trail styles. Purely visual to avoid gating fun behind grind. Risk: the current palette is tightly curated; poorly chosen cosmetics dilute the art direction.

### Be careful with

- **Daily rewards / streak bonuses for *showing up*.** Different from an in-run streak. Crosses into dark-patterns territory; alienates players who treat this as a pick-up-and-put-down game.
- **Ads.** Would erode the "one more run" loop more than almost any design choice listed here.

---

## 4. Technical / Engineering

### Worth doing

- **Extract a pure-Dart simulation test suite.** `GameState` is already engine-free and viewport-injected — it's set up for this. Tests for: difficulty curve monotonicity, meter drain/fill equilibrium, collision correctness at edge cases, near-miss tier thresholds. Currently only [test/smoke_test.dart](test/smoke_test.dart) exists.
- **Rename the package from `basic` to `chrono_swipe`.** Imports like `package:basic/main.dart` (see [test/smoke_test.dart](test/smoke_test.dart#L1)) are a tripwire for contributors and for platform-integration work. The [`rename`](https://pub.dev/packages/rename) package automates it; do this before any serious integration work.
- **Delete the template leftovers already staged as deletions.** The working tree has uncommitted deletions of `level_selection/`, `play_session/`, `player_progress/`, `win_game/`, etc. Committing the removal is a small bookkeeping step that clarifies the architecture for every future reader.
- **Golden tests for the painter.** The game is defined visually; `flutter_test` supports golden image tests out of the box. A few well-chosen snapshots (idle backdrop, mid-run with obstacles, crash frame) guard against rendering regressions from refactors.
- **Extract tuning constants to a single `GameTuning` class.** Today the constants live at the top of [lib/game/game_state.dart](lib/game/game_state.dart); they're all `static const`. Moving them to their own file makes A/B testing different feels trivial (swap the import) and declutters the simulation code.

### Worth considering

- **Web build + playtest page.** `flutter build web` plus a GitHub Pages deploy would turn every design tweak into a shareable link. `audioplayers` has known quirks on web — budget time for that.
- **Replay recording.** Given a seed + input timeline (`playerXTarget` deltas + chrono-active bits at fixed tick), runs are deterministic and tiny to store. Unlocks ghost mode, bug reports with repro, and highlight clips. Requires pinning the simulation to a fixed tick rate (it isn't today — it uses the Flutter `Ticker`'s variable dt).
- **Fixed-timestep simulation with interpolated rendering.** Needed for determinism (replay, daily-seed fairness across devices). Non-trivial refactor; don't do it speculatively. Only pursue if replay or leaderboards land on the roadmap for real.
- **Performance pass on web.** `MaskFilter.blur` in [lib/game/game_painter.dart](lib/game/game_painter.dart) is called per obstacle per frame. On web/CanvasKit this is likely the dominant cost. Consider pre-rendering glow sprites once per color into a small atlas.

### Be careful with

- **Introducing Flame or another engine.** Current stack (`Ticker` + `CustomPainter` + `ChangeNotifier`) is a feature, not a limitation — it's ~600 lines and fully understood. Migrating buys nothing the game actually needs.
- **Splitting `GameState` prematurely.** It's one file doing one thing. "Separation of concerns" refactors here would trade legibility for ceremony. Wait until a concrete second consumer appears.
- **Adding `build_runner` / code generation.** README specifically praises the absence of it. Keep it that way unless a dependency forces the issue.

---

## Cross-cutting: what would make the *biggest* difference?

If forced to pick three:

1. **Haptics.** One-line change, transforms the feel on the platform most people will play on (iOS). Unambiguous win.
2. **Ghost of best run.** Uses systems the game already has (trail rendering, local persistence), adds the single strongest motivator for "one more run" short of a global leaderboard.
3. **Pure-Dart simulation tests.** Not a player-facing feature, but every other idea on this list becomes cheaper and safer to ship once they exist.

Everything else is a question of taste, time, and whether the game finds players.

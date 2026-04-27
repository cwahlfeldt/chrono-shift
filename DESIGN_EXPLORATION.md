# Chrono-Swipe — Design Exploration

A working document for evolving Chrono-Swipe around its most interesting accidental property: **the player's finger is the time machine**.

This is not a redesign. The current game works. The intent here is to recognize a mechanic that emerged from the input layer, name it, and explore how to make it the soul of the game rather than a quirk.

---

## 1. The current loop, in plain language

You are a glowing dot dragged forward through a neon corridor. The corridor never stops, never branches, never ends — only narrows. You touch the screen to keep yourself alive. You let go to recover.

Strip everything else away and the moment-to-moment loop is:

1. **A wall is coming.** It has a gap. You are not lined up with the gap.
2. **You touch the screen.** Time slows. You move your finger across the screen and your craft follows.
3. **You shave the edge of the gap.** A near-miss flashes; the meter refunds a small amount; the streak ticks up.
4. **You let go.** Time accelerates back. The corridor speeds up. The next wall is already on screen.

That's the whole game. A run is roughly 30–120 seconds of repeating that beat under steadily increasing pressure (faster scroll, narrower gaps, more obstacle types).

### Mechanical inventory

| System | What it actually does |
|---|---|
| Forward speed | `baseSpeed` (520 px/s) + a distance ramp up to `+380 px/s`. Multiplied by `timeScale`. |
| Chrono-shift | Smoothly lerps `timeScale` from `1.0 → 0.2`. Drains a `0..1` meter at `0.55/s`, refills at `0.32/s`. Drain is faster than fill — slow-mo cannot be the default state. |
| Steering | Pointer delta maps 1:1 to a target-x; player lerps toward target. Crucially, the steering lerp uses **real** dt, not dilated dt — the craft does not feel sluggish during slow-mo. |
| Near-miss | Three tiers (16/28/44 px from a gap edge), worth 40/80/120 points and refunding 5/10/18% of the meter. Pillars get two tiers. |
| Streak | Each near-miss adds 0.15× to a multiplier (capped at 2.35×). Decays after 2.5 seconds without a fresh miss. |
| Score | `forwardSpeed × dt × 0.1 × chronoScale × streak`, where `chronoScale = 2.2` while shifted. Slow-mo more than doubles your point rate. |

### What the player is actually balancing

Three resources, three timers:

- **The meter** — finite slow-mo. Refunds only via tight near-misses. If you spend it on a clean middle-of-the-gap pass, it leaks away forever.
- **The streak window** — 2.5 seconds. A clean, easy pass between two tense ones loses your multiplier even if you don't crash.
- **The corridor itself** — speed and gap width are getting worse every second. Hesitating is a tax.

The whole design rhymes with the same idea: **playing safe is a slow loss**. There is no equilibrium where caution keeps you alive forever; the difficulty curve guarantees a crash if you don't actively chase near-misses to keep the meter and streak fed.

---

## 2. What the one-finger control scheme is doing well

The current scheme bundles three verbs into a single input channel:

- **Touch down + hold still** → engage chrono (after a 50 ms hold guard).
- **Touch down + drag** → steer (and, by virtue of contact, also engage chrono).
- **Release** → exit chrono.

This is the part the design doc undersells. The input is not "two buttons collapsed to one." It is a single continuous gesture with **simultaneous semantics**, and the player's body cannot do one without doing the other. That's an unusual property worth dwelling on.

### Why "one finger" works for this specific game

- **No HUD-to-hand mismatch.** A separate slow-mo button would make the player choose where to look — at the corridor or at the button. Here the corridor is also the button.
- **The hand can't lie.** In a two-button scheme players can spam a slow-mo toggle defensively. Here, slowing time has a physical cost: you must commit your only steering finger to it, with the finger placed where you happen to need it, not where a UI element decided to live.
- **Tactile honesty.** Lifting the finger is the only way to exit chrono. There is no "release after a frame" exploit. The body and the simulation agree on what happened.
- **Approachable, not shallow.** A non-gamer can learn the scheme in three seconds (touch screen, drag) and *also* immediately discovers the slow-mo without being taught — they hold the screen because they're scared, time slows, and the game has just finished its own tutorial.

This is the rare control scheme where reducing the input *increases* the depth, because every gesture now means more than one thing at once.

---

## 3. The accidental mechanic: movement *is* time manipulation

Here is the observation that this document is built around.

**Because steering requires a finger on the screen, every steering input is also (after 50 ms) a chrono activation.** The 50 ms guard in [game_tuning.dart:58](lib/game/game_tuning.dart#L58) is just long enough to let a flick-and-release tap pass through without slowing time — but any *sustained* steering, the kind you actually need to thread a gap, slows the world.

The player has noticed this and is right: **it feels great**, and it isn't really a side effect anymore. It's the core verb of the game, and it's being framed (in copy and HUD) as if it were two separate verbs.

What this overlap actually creates:

- Steering and time dilation are not two abilities you stack — they are **the same ability**, viewed from different angles. The cost of moving precisely is the cost of slowing time. You cannot pay one without paying the other.
- The action-movie fantasy from the design doc lands more cleanly than the doc itself describes. You don't "decide to slow time, then steer." You **reach for the obstacle**, and the world bends to give you the time to reach it. The slow-mo is a property of paying attention, not a separate decision.
- It collapses the "should I shift?" question. There is no "should." If you are steering with intent, you are already shifting. The interesting question becomes *how long to keep your finger down after you're lined up*, which is a much richer question than "shift / don't shift."

The current copy ("DRAG to steer · HOLD to slow time") sells these as two distinct verbs. The mechanic — and the player's intuition — say they are one verb with two effects. **The game's identity should follow the mechanic, not the copy.**

### The reframing

> **Chrono-Swipe is a game about touching the screen to bend time toward your hand, and letting go to give time back.**

Movement is the input; time-warp is what movement *is*. Releasing isn't "stop slowing" — it's an active commitment to real-time, paid in nerve, that fills the meter back up. The dichotomy isn't shift / steer; it's **engaged / committed**.

---

## 4. Why the swipe-to-slow-time feel works

A few specific properties of the current implementation make this overlap satisfying rather than confusing:

1. **Steering uses real dt.** [game_state.dart:212-216](lib/game/game_state.dart#L212-L216) — the craft follows the finger at full responsiveness even while the world is slowed. So when you swipe through chrono, your hand and the craft stay 1:1, but the *world* concedes ground. The player feels superhumanly fast relative to the obstacles, not slow.
2. **The meter drain is real-time too.** [game_state.dart:267](lib/game/game_state.dart#L267) — slowing time doesn't slow the cost of slowing time. So a longer swipe = a more expensive swipe, exactly as the body expects.
3. **Time-scale is smoothed, not stepped.** [game_state.dart:276](lib/game/game_state.dart#L276) — there's a ~70 ms ease into and out of slow-mo, so a swipe feels like the world *gives way* under your finger, not like pressing a brake pedal.
4. **The visual chrono tint is proportional to `(1 - timeScale)`** [game_painter.dart:50](lib/game/game_painter.dart#L50). Mid-swipe — when the world is half-slow — the screen is half-tinted. The game tells the truth about how engaged you are, in an analog way.
5. **The 50 ms hold guard hides the seam.** [game_tuning.dart:58](lib/game/game_tuning.dart#L58) — a deliberate quick-flick tap registers as steering only. Anything longer is "intentional contact" and time bends. Most players will never consciously notice this threshold, but it's the reason the system doesn't feel jittery.

The slow-mo arrives, in other words, *exactly when the player is asking for it*, because asking for it and steering are the same gesture. Every part of the technical implementation supports that illusion.

---

## 5. Strengths and weaknesses of the current build

### Strengths

- **One-gesture mastery curve.** A new player can play; an expert player feels different in their hand. Same input, different relationship.
- **Tight risk/reward calibration.** Tier-3 near-miss refunds (`+18%`) genuinely repay the chrono-meter cost of a 1–2 s shave, so aggressive play is *self-sustaining* — exactly the doc's intent.
- **Score doubling during chrono.** [game_tuning.dart:96](lib/game/game_tuning.dart#L96) — the `2.2×` multiplier turns the safety net into the offensive weapon, which is the design's central elegant move.
- **No menus inside a run.** The whole game is the corridor.
- **Honest haptics.** [play_screen.dart:150-177](lib/game/play_screen.dart#L150-L177) — a tick on chrono engage, a thump on near-miss, a heavy on crash. The body knows what happened before the eyes parse it.

### Weaknesses

- **The HUD describes two verbs.** "DRAG to steer · HOLD to slow time" trains the player to think of these as separate. The mechanic disagrees.
- **Score-during-chrono is a flat 2.2×.** It rewards *being* in chrono, not being in chrono *meaningfully*. A perfect-line cruise through an empty stretch with the finger held down is worth as much per pixel as a knife-edge thread. The game is leaking expression here.
- **No "release moment" reward.** The fantasy is "slow time, thread the needle, **let go**." But letting go is currently just a state change — there's no ping, no score event, no feedback that the *commitment to real-time* was the brave act. The whole emotional arc loses its punctuation.
- **Streak decay is uniform.** 2.5 s for any miss tier. A tier-3 PERFECT and a tier-1 graze keep the streak alive equally long. There's a missed coupling here between *how well* you played and *how much room the game gives you to follow up*.
- **Obstacle vocabulary is small (4 kinds).** The corridor doesn't ask different questions of the player; it asks the same question harder.
- **No way for a confident player to opt into more risk.** Pressing harder, longer holds, dramatic gestures — none of these change the physics. The only knob the expert has is "how close to the edge can I shave."
- **Idle/empty corridor stretches feel flat in chrono.** When there's nothing to dodge, slowing time costs you points (relative to what you'd be earning at full speed) without giving anything back. The game silently punishes you for chrono'ing during a lull, but doesn't tell you.
- **Crash is binary.** One brush, run over. For an arcade game this is fine, but it leaves no room for *recoverable* mistakes, which would let the chrono mechanic do dramatic last-second saves — the most cinematic version of itself.

---

## 6. Making chrono-shift the identity, not the side effect

Six design directions, ordered from "smallest change, biggest payoff" to "would reshape the game most."

### Direction A — Reframe the verb (copy + tutorial)

Smallest change. Highest immediate payoff.

- HUD line: drop the dual phrasing. Try **"REACH to bend time"** or **"TOUCH to slow · RELEASE to fly"**. The new framing teaches the player that *contact itself* is the time-bending act, not a secondary feature behind a hold.
- Tutorial moment on first touch: a single line of text fades in — *"Time bends toward your finger."* — then fades when they let go.
- Rename the meter in HUD from CHRONO to **NERVE** (or REACH, or HOLD). It's not a fuel tank; it's how long you're willing to commit. Right now the noun "chrono" hides what the bar measures from the player.

This is a 30-minute change and it converts the entire mechanic from "trick I learned" to "thing the game told me about."

### Direction B — Reward the release, not just the hold

Currently the game rewards being slow (2.2× score). Reframe it to reward the **transition from slow to fast at the right moment**. This makes the *whole gesture* — touch, thread, release — the scoring unit, not just the slow part.

Concrete proposal: a **Release Bonus**.

- When the player lifts off the screen *within ~250 ms after passing an obstacle's worldY*, award a "CLEAN RELEASE" bonus, scaling with how slow time was at the moment of pass and how tight the near-miss was.
- Visually: the screen un-tints with a small white flash and a gold particle puff at the release point. Audibly: a rising "snap" tone.
- The on-screen text reads **"SNAP"** or **"LET GO"** for a beat.

What this does:
- Closes the action-movie loop. The hero doesn't sidestep the bullet by going slow forever — they go slow, dodge, and **explode back into real-time**. The game now rewards that whole arc.
- Discourages "finger camping" — holding the screen the whole run as a defensive habit. Players who never release lose access to the SNAP bonus and so leave score on the table.
- Gives the meter a third life: drain (committed), fill (resting), and the *moment* of release (climactic).

### Direction C — Make slow-mo expressive, not flat

Right now `timeScale` is binary in intent (1.0 or 0.2). Players can't *say more* with the gesture.

Two compatible variants:

1. **Pressure-modulated slow-mo (mobile only).** On supported platforms, force-touch / 3D-touch / pressure values modulate `slowFactor` between, say, `0.5` and `0.15`. Light contact = mild dilation; firm press = deep slow-mo. The meter drains proportionally to how slow you've made it. This makes the *intensity* of contact a direct expression of the "how scared am I" state.
2. **Hold-depth ramp (no special hardware).** The first 200 ms of contact slow time only to ~0.6×. The next 400 ms ease down toward 0.2×. So a quick steering touch barely bends time, but committing to a long thread takes you fully under. Drain rate ramps up with depth too, so the meter cost matches.

Either way, the player gains an analog expression channel through the same finger. The expert can say "I need a touch of time" or "I need to *stop* time" with their hand. The novice never has to know — short contact still gives them the time they need.

### Direction D — Couple the world to the gesture

The world should look and feel different *because the player is reaching*. Right now there's a cyan tint, brighter glows, a star-trail recede. That's atmospheric, but it's painting the player's input rather than reacting to it.

Ideas, all small:

- **Obstacles "perceive" the player during chrono.** A nearby wall's gap edges shed extra particles toward the craft, or its glow brightens within ~150 px of the player. Cinematically: the world acknowledges that you're paying attention to it.
- **Trail color codes commitment.** Today: gold normal, cyan in chrono. Variant: brighter cyan the *deeper* you are in chrono (couples to Direction C), or gold-cyan gradient through the trail showing your recent decision history. The trail becomes a rolling read of how brave you've been.
- **Audio: pitch-shift the bed during chrono.** The forward-rush whoosh shifts down an octave during slow-mo, then snaps back on release. This is one of the cheapest, most viscerally rewarding feedback channels and is currently unused.
- **Camera "leans" with the finger.** A subtle 4–8 px parallax offset of the obstacle layer toward the player's x while chrono is engaged. Visually communicates that touching the screen is *pulling the world*, which is exactly what the mechanic feels like in the hand.

### Direction E — New mechanics that build on "movement = slow"

Mechanics that only work because the player's finger doubles as the time-bender:

1. **Quick-tap double-touch reset.** A second finger tapping briefly anywhere on the screen acts as a "burst" — instant 100 ms of full-stop time, paid for at 25% of the meter, regardless of where the steering finger is. Lets the expert handle a snap-emergency without lifting their steering finger. Single-finger players never need this.

2. **Echo trail.** While in chrono, a faint after-image of the player's path is briefly drawn on screen. After a near-miss, the after-image *flicks forward* and grants a small score bonus matching its position's tightness. Mechanically: the game rewards a clean curve, not just a clean point. Encourages graceful arcs instead of jittery corrections.

3. **Stillness premium.** If the player holds chrono *without moving* their finger more than a few px for >0.5 s, a "STILLNESS" bonus accumulates at a slow trickle. Counterbalances the score loss in empty corridor stretches and rewards the patient, set-up-the-shot kind of play that the current game accidentally punishes. The fantasy: the bullet is in the air, you are perfectly still, you wait.

4. **Counter-steer dives.** A sharp swipe in the *opposite* direction of momentum during chrono produces a quick lateral burst (player snaps a small distance with a momentary trail flash). Costs a flat 8% of the meter. Lets the player solve diagonals in one expressive gesture instead of tracking the wall. This adds a skill ceiling to steering itself: experts can recognize a diagonal early and "dive" through it; novices cross it the slow way.

5. **Phase obstacles.** A new obstacle type that is *only solid when time is at full speed*. A glittering ghost-wall that you can pass straight through if you're chrono-shifting. Inverts the usual logic — chrono is no longer just safety, it's a key. Forces the player to *want* to be in slow-mo at certain moments, even when no near-miss is on offer. Pairs beautifully with Direction B's release-bonus, because mistiming the release into a phase wall is now a sudden loss.

6. **Anti-phase obstacles.** The mirror: walls that are only solid *during* chrono. Now slowing time is a liability in those segments. The player has to read the corridor and decide whether to commit. This is the cleanest possible design for a "chrono is a tool, not a crutch" lesson.

7. **Time-locked pickups.** Sparkling motes drifting in the corridor that can only be collected while in chrono (they're moving too fast otherwise). Score on collect; small chrono refund on collect. Adds *positive* targets to the corridor, not just negative ones. A player who is bad at near-misses but good at threading still has a way to score.

### Direction F — Progression and meta-loops without breaking minimalism

The game is structurally a single endless run. That's right for what it is. But there are lightweight ways to give players something to chase across runs without adding menus or unlocks.

- **Daily corridor.** Every player gets the same procedural seed for the day. A small "today's best on this seed" slot in the HUD. Encourages return play and gives the player a fixed reference for whether they're improving.
- **Run modifiers earned by score.** Pass 10k once and unlock the option to start a run with a 50% meter (and a name like "GLASS"). Pass 50k and unlock "MIRROR" — corridor flipped horizontally. These don't gate anything; they're toys. Each one is a single boolean in `GameState` and a few lines in `_spawnObstacles` / steering.
- **Personal-best ghost.** During a run, draw a low-alpha trail showing where your previous best run was at this distance. The player races their own past hand. Costs ~20 floats stored per run.
- **Chrono-economy badges.** Show, on the game-over card, your *meter efficiency* — points per percent of meter spent. A player aiming for "perfect economy" plays differently from one chasing raw score, and giving them a number to hill-climb opens a second meta-objective without changing gameplay.

---

## 7. Risk/reward opportunities tied to slowing time

Specific levers that turn chrono from "spend it carefully" into "spend it *interestingly*":

| Lever | What it does | Why it's interesting |
|---|---|---|
| **Late-shift bonus** | Engaging chrono in the last ~150 ms before a wall (rather than ahead of time) gives a 1.5× near-miss multiplier. | Rewards reading the obstacle and reacting late, the action-movie beat. Punishes paranoid early-shifts. |
| **Cold thread** | Passing an obstacle *without* engaging chrono in the previous second gives a "COLD" bonus. | Gives non-chrono play a meaningful score reward. Incentivizes cherry-picking which obstacles are hard enough to deserve a shift. |
| **Overdraw penalty** | If the meter hits zero mid-thread (auto-eject from chrono), the next obstacle's near-miss tiers temporarily shrink. | Adds a "running out of nerve" cost, currently absent — right now meter exhaustion is just an inconvenience. |
| **Streak banking** | At any near-miss, a quick *upward* swipe (instead of left/right) "banks" the current streak as a flat score deposit and resets it. | Gives the player an explicit moment of greed-vs-fear: take what you have, or push for more? Adds a third gesture without adding a third button. |
| **Burn-down combo** | Three tier-3 near-misses in a row triggers a brief "BURN" state — chrono is free for 1.5 s, but if you crash during it the game-over score is halved. | A high-risk reward state for experts. Most players never see it; those who do get the game's most cinematic moment. |

These are not all compatible. Pick the two that best support the identity ("contact = bending time"). My picks: **Late-shift bonus** + **Cold thread**, because together they make the player ask, *for each obstacle*, "is this one worth a touch?" — which is the question the game's input is built around.

---

## 8. Feel, readability, and pacing fixes

Smaller polish items that don't need a design pillar to justify:

- **Tell the player when chrono is wasted.** During empty stretches with chrono active, fade the meter bar slightly red or play a subtle "leaking" tick at 1 Hz. Currently the meter just drains silently — the player has to learn through losses that they shouldn't shift on empty corridor.
- **Release should be felt.** Add a single haptic `lightImpact` and a short white-fade on release while time-scale was below ~0.5. Currently release is silent in every channel; it should be the most cathartic moment of the run.
- **Near-miss flash should depend on tier.** PERFECT vs NEAR MISS already differ in color and size. Make tier-3 also slow time another 50 ms after the pass (a "bullet-time confirmation") and tier-1 punch a faster snap. The text alone doesn't differentiate enough at speed.
- **Obstacle approach telegraph.** Walls fade in over ~100 ms when first spawned, but they spawn *outside* the visible viewport. Inside the viewport they pop. A subtle pre-glow on the bottom edge of the screen ~250 ms before an obstacle scrolls onto it would let chrono'd players prepare without slowing them down further.
- **Streak audio.** A soft pitch-rising tone every streak step (max 9 → 9 audible notes). Right now the streak number is the only indicator; an ascending arpeggio tells the body it's climbing.
- **Show the cost.** Above the meter bar, briefly draw a "−X%" counter next to the existing "+X%" refund counter when chrono drains past a threshold. Symmetry with the refund display.
- **Death camera.** On crash, hold the slow-mo for 400 ms even if it wasn't active — let the player *see* what they hit. Currently the crash is too fast to read and the lesson is lost. This is the one place where slow-mo should be free.

---

## 9. Preserving simplicity

Across all of the above, a few rules to enforce so the game doesn't drift:

1. **One finger remains sufficient.** Anything that requires multitouch (the double-tap burst in Direction E) must be optional and discoverable, never required. A player who never lifts their second finger should still have a complete game.
2. **No menus inside a run.** Pause is fine; configuration is not. Modifiers like Daily / Glass / Mirror live on the main menu and are *committed to* before the run starts.
3. **The HUD must fit in one row + one bar.** Adding a fourth or fifth thing to track in real-time breaks the fantasy of "your whole attention is on the corridor."
4. **No tutorial overlay.** Anything new must be teachable through one round of play. If a mechanic needs an explanation screen, it's the wrong mechanic for this game.
5. **Every new obstacle type must ask a different *question*.** Walls = "where's the gap?" Combs = "which lane?" Diagonals = "how fast can you shift?" New types must add a verb, not just a shape.
6. **Slow-mo must always cost something.** Free chrono is allowed only as a transient state (the BURN combo, a phase-wall puzzle), never as a baseline. The whole game falls apart if the meter stops mattering.

---

## 10. Recommended near-term path

If I had to pick the smallest set of changes that would most strongly establish chrono-as-identity, in order:

1. **Reframe the verb in copy and HUD** (Direction A). Free, takes an afternoon, sets the table for everything else.
2. **Add the Release Bonus** (Direction B). The single highest-leverage mechanical change — it completes the action-movie arc the design doc is reaching for and adds a new score event the player can chase.
3. **Add Late-shift bonus + Cold thread** (Section 7). These two together turn each obstacle into a small live decision: "shift or no?" Right now that decision is muddled because shifting is almost always correct. With these, it isn't.
4. **Polish the release moment** — haptic, audio pitch-bend, white snap (Sections 4 and 8). The release is currently the silent half of the gesture; making it loud is the cheapest emotional upgrade in the game.
5. **Add Phase obstacles** (Direction E.5). The first new obstacle type in a while, and the one that most cleanly inverts the game's dominant logic, teaching players that chrono is a tool with two sides.

Everything else in this document — pressure modulation, echo trails, daily seeds, ghost runs, modifiers — is a fertile second pass once the core identity is locked in.

---

## Appendix — files most likely to change

For anyone implementing from this document:

- [lib/game/game_tuning.dart](lib/game/game_tuning.dart) — every numeric knob. New tuning constants for release bonus, late-shift window, cold-thread window, burn duration, etc.
- [lib/game/game_state.dart](lib/game/game_state.dart) — the simulation. New fields for release-bonus pending state, chrono-engagement timestamp (for late-shift), time-since-last-chrono (for cold thread), phase-obstacle handling.
- [lib/game/play_screen.dart](lib/game/play_screen.dart) — input. Pressure events, double-tap detection, upward-swipe detection if streak-banking is added. Also the haptics dispatcher.
- [lib/game/game_painter.dart](lib/game/game_painter.dart) — visual feedback. Release flash, deeper-chrono tint ramp, phase-obstacle ghost rendering, lean-with-finger parallax.
- [lib/game/models.dart](lib/game/models.dart) — new `ObstacleShape.phase` (and possibly `antiPhase`).
- [GAME.md](GAME.md) — the public design doc should follow whatever direction the team picks here.

# Chrono-Swipe

## Overview

Chrono-Swipe is a fast-paced, one-more-run arcade survival game about threading impossibly tight gaps at high speed — and bending time when you can't. You pilot a single point of light rocketing forward through an endless corridor of neon obstacles. The longer you survive, the faster you go, and the tighter the gaps become. Your only lifeline is the Chrono-Shift: a finite pool of slow-motion that you can dip into at any moment to buy yourself the fractions of a second you need to make it through.

The game is designed for short, intense runs — a minute or two at a time — where every session either ends in a clean new personal best or a spectacular crash.

## Core Fantasy

You are moving too fast to react. Your brain and fingers cannot possibly keep up with what's coming at you. So you cheat — you slow time itself, thread the needle, and let go. The feel the game is reaching for is that moment in action movies where the hero sidesteps a bullet.

## How You Play

- **Steer** left and right to move your craft across the track.
- **Hold** to activate Chrono-Shift, which slows the world to roughly 20% speed. Release to snap back to full speed.
- Survive as long as you can. There is no finish line — only a high score.

## The Chrono Meter

Chrono-Shift is not free. A meter (shown as a percentage) drains while you're slowed and refills while you're not. At zero, time resumes at full speed whether you're ready or not.

The meter reshapes every decision in the game:

- **Drains faster than it refills.** You cannot simply hold slow-motion the entire run.
- **Runs score faster while slowed.** Points come in roughly 2x faster during Chrono-Shift, rewarding players who use it for offense rather than pure survival.
- **Forces commitment.** When you dip into the meter on one obstacle, you may not have it for the next one. Managing this reservoir over the course of a run is the central puzzle.

## Obstacles

The track throws a procedurally mixed stream of obstacle patterns at you, each tuned to a different kind of reaction:

- **Walls** — a full-width barrier with a single gap to thread.
- **Slabs** — paired walls stacked in quick succession, with their gaps offset so you must steer between them without overshooting.
- **Combs** — a row of pillars with one open lane. Pick your lane early or get funneled into a wall.
- **Diagonals** — two walls where the safe gap jumps sideways between them, demanding a fast lateral shift.

Gaps narrow and spacing tightens as your distance grows, so the same pattern that felt generous in the opening seconds becomes a knife-edge later in the run.

## Scoring

Score accumulates continuously from forward speed. On top of that baseline:

- **Chrono multiplier.** Slowing time roughly doubles the rate at which you earn points.
- **Near-misses.** Passing an obstacle with your craft close to the edge of the gap awards a bonus, with bigger bonuses for tighter shaves. A "NEAR MISS" flash confirms the read.
- **Streak multiplier.** Stringing near-misses together builds a combo multiplier (up to roughly 2.35x) that amplifies everything you earn. Go too long without a near-miss and the streak decays.

The game stores your best score locally and celebrates beating it.

## Difficulty Curve

There is no level select, no menu of modes — difficulty is purely a function of how far you've gone. As distance accumulates:

- Forward speed increases.
- Gaps narrow.
- Spacing between obstacles tightens.
- New obstacle types enter the rotation — first walls only, then combs, then the full mix — so the early game teaches the vocabulary before the late game tests it.

## Feel and Presentation

The visual language is deliberately minimal: a dark field, a handful of accent colors (cyan, gold, red), and a glowing ball of light for the player. Everything bends around the act of moving fast and slowing down.

- Activating Chrono-Shift shifts the color palette, brightens obstacle glows, and leaves a cyan trail behind the player. At normal speed, the trail is gold.
- A starfield parallax and a central stripe pattern sell the sensation of forward motion.
- Crashes are cinematic: screen shake, a burst of particles in red/gold/cyan, a brief flash, and a slow fade-out before the score screen.
- Near-misses produce a short particle burst and an on-screen callout.

## Why It Works

The design hinges on a single, clean tension: the thing that saves you is also the thing that scores you. Chrono-Shift is simultaneously your safety net and your point multiplier, so the player who hoards it plays safe and scores poorly, while the player who burns it aggressively lives on a thinner edge but climbs the leaderboard faster. Every run becomes a negotiation between those two instincts, and the short session length — often under two minutes — makes it easy to commit to "one more try."

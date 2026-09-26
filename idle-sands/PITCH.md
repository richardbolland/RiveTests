# Idle Sands — Pitch

A whimsical beach idle/clicker. You dig the sand for junk and treasure, sell what
you find, and spend the money on upgrades and specialist digger bots that
automate the collecting for you while you're away from the keyboard.

**Core loop:** Producers dig on their own, always — clicking one just speeds
it up. Collect items → sell for currency → buy upgrades/bots → more
producers, each auto-collecting and each click-boostable → repeat, idly,
forever. (Revised from an earlier click-to-collect design after milestone 3
playtesting — see PLAN.md for the reasoning.)

**Genre & tone:** Idle/incremental, browser-playable, humour-heavy writing with
an environmental-cleanup undercurrent (you're picking junk off a beach). Playful
and self-aware — puns, silly item descriptions, meme-adjacent bot names — never
mean-spirited.

**Original:** Built in Unity in 2023 by Studio Bolland, shipped to itch.io. This
is a from-scratch recreation in Rive, built CLI-first with an agent, favouring
Rive-native mechanisms (data binding, Lists, state machines) over a literal
port of the Unity architecture.

**Visual direction:** Flat vector "sticker" style, built directly in RML rather
than imported art — clean shapes, bold outlines, no photographic/PSD assets.
Palette is a single global set of design tokens (a colour view model) so the
whole game can be re-themed later by swapping token values, not hunting through
markup. Starting palette: warm sand, ocean blue, coral accent — free rein
beyond that.

**Scope for this build:** Smallest playable slice first — 2 bots, 6–8 items —
with the full spec (4 bots, 18 items, achievements) layered in as later
milestones once the core loop is solid. Dollar values and timings from the
original are a starting point, not gospel; rebalance once it's playable.

**Explicitly out of scope for v1:** Ad integration, "earn while the tab is
closed" idle catch-up, vertical/portrait responsiveness. Persistence
(save/load while playing) and horizontal responsive layout ARE in scope early.

**Shipping target:** Both `rive --publish=web` (Rive's own hosted page) and a
GitHub Pages build using the Rive web runtime, from the same signed `.riv`.

**Fantasy:** You're a small-time beach scavenger who builds up a fleet of
increasingly ridiculous robot helpers to strip a beach clean of bottle caps,
nails, and the occasional diamond ring — half honest hustle, half get-rich-
quick scheme.

# Idle Sands — Plan

See PITCH.md for direction. This file is re-read at the start of every work
session; keep it current as milestones land or scope changes.

## Game design (v1 slice)

- **Items (6–8, starting tier):** Bottle Cap, Nail, Tin Can (Beach Boy's items),
  Screw, Key, Coin (Steel Seeker's items). Values and flavour text ported from
  the original brief, editable later.
- **Bots (2, starting tier):** Beach Boy ($458) and Steel Seeker ($1,087), each
  locked to its three item types.
- **Upgrades (3):** items-per-dig, dig speed, auto-sell timer — flat 110-gold
  cost per level, as in the original.
- **No achievements, no ads, no vertical layout, no offline-catch-up in v1.**
  Each is a candidate for its own milestone after the core loop ships.

## Core loop

**Revised after milestone 3's playtest** (see the design/UX entries below for
the full history): the beach item is an **always-on auto-collector**, not a
click-to-collect spot. It runs its own cycle continuously — collects
itemsPerDig items and restarts, with no interaction needed at all. Clicking
it never collects directly; a click just cuts a percentage off whatever time
is left on the current cycle, speeding it up. Idle play works from second
one; clicking makes it faster. Beach Boy and Steel Seeker (milestones 4/5)
are additional producers of the same kind — their own independent cycle,
their own click-boost, their own item pool — not a separate mechanic.

Items land in inventory (12 slots) → sell manually via Sell All → currency
increases → spend on upgrades/bots → more producers, each auto-collecting
and each click-boostable.

## Rive architecture

- **One global View Model (`Economy`)**: account-wide stats only —
  currency, itemsPerDig, digSpeedSeconds, elbowGreasePercent,
  autoSellSeconds, gameTime, the shared `inventory` list, and each
  panel's affordable/cost-label state. Everything on screen binds to
  this — no manual UI refresh code.
- **One `Producer` view model** (producers.rml), one instance per owned
  producer (the free starter, then each purchased bot): its own
  `lastDigTime`/`digCooldownFraction`/`itemPulseScale`/pulse/popup state,
  plus `swatch` (colour) and `itemPoolName`. `Economy.producers` is a
  list of these, rendered through a reusable `ProducerWidget` artboard
  (an `ArtboardComponentList`, same mechanism as the inventory rows) —
  the beach area is "one widget per owned producer," starting at one.
  Buying a bot pushes a new instance onto the list; there is no
  "owned but inactive" state to track.
- **One invisible driver script** (`clock.luau`, a zero-size
  `ScriptedLayout`): owns `advance(self, seconds)`. Ticks `gameTime`,
  then iterates `Economy.producers` running the identical auto-collect
  cycle for each row — collects when a producer's own remaining time
  hits zero, picks a weighted-random item from *that producer's*
  `itemPoolName` pool, restarts its cycle. Also computes every upgrade
  panel's affordable/maxed state and the live inventory total. This plus
  the per-row click-boost script (`main.luau`, living inside
  `ProducerWidget`) are the only Luau in the project for v1 — everything
  else stays in RML/state machines per the scripts-are-for-computation,
  not-interfaces rule in the CLI docs.
- **Inventory & producer rows**: Rive `List`/`ArtboardComponentList`
  bound to view-model arrays, not hand-placed instances — the same
  mechanism serves both, and adding a third list (achievements, say)
  later is the same pattern again.
- **Colour tokens**: a second small global View Model (`Theme`) holding named
  colour properties (background, accent, text, etc.), bound throughout via
  data binding, so re-theming later is "change 6 values" not "hunt through
  markup."
- **Layout**: Rive `LayoutComponent` flex/grid, horizontal-only responsiveness
  (fill/hug scaling across widths), no portrait-specific breakpoints for v1.
- **Persistence**: not a script concern — the *host* HTML/JS page reads the
  `Economy` view model's values via the Rive web runtime's data-binding API,
  writes them to `localStorage` periodically and on unload, and writes them
  back into the view model on load. Lands as its own early milestone once the
  view model shape is stable.
- **Tooltips**: item/bot descriptions kept verbatim from the original brief,
  shown via a state-machine hover state, sourced from a text property on each
  item/bot's view model instance rather than duplicated per-artboard.

## Asset list (all built as vector shapes in RML, no imported art)

- 6 item icons: Bottle Cap, Nail, Tin Can, Screw, Key, Coin
- 2 bot character icons: Beach Boy, Steel Seeker
- Beach background (simple flat shapes/gradient, sand + water line)
- UI: currency readout, dig button/area, 3 upgrade panels, 2 bot-purchase
  panels, 12-slot inventory grid, sell button, tooltip component
- Style notes: bold flat outlines, pastel-leaning but beach-toned palette
  (sand/ocean/coral), consistent corner-radius language across panels and
  item "stickers"

## Milestones

Each one should build clean (`--verify`), inspect with zero wiring problems,
screenshot to confirm it looks right, and be played/approved before starting
the next. Commit after each.

0. ✅ **Skeleton** — empty scene, `Economy` and `Theme` view models declared with
   placeholder values, base layout wireframe (top bar / beach area / side
   panel / inventory strip) as flat filled boxes. `--verify` clean.
1. ✅ **Click-to-collect, single item** — one item type spawns on click in the
   beach area, clicking it adds 1 to currency (bound, visible readout). No
   economy depth yet — proves the click → view-model → UI pipeline end to end.
   Found: `context:globalViewModel()` returns nil on a script's first `init()`
   call — cache `Context` and resolve the view model lazily instead.
2. ✅ **Full starting item set + inventory** — 6 items with real values, dig
   spawns a random item from the pool, items land in the 12-slot inventory
   List (not straight to currency), manual "Sell All" button converts
   inventory to currency. Needed `rive.yaml`'s `main:` key once the project
   spans multiple `.rml` files, since they compile in path order.
3. ✅ **Upgrades** — items-per-dig, dig speed, auto-sell-timer panels, each
   purchasable at 110 gold/level (one shared `upgrade.luau`, parameterised per
   panel via `ScriptInput*`). itemsPerDig and dig-speed cooldown are live now;
   auto-sell's timer value is purchasable but its passive-sell behaviour
   still lands in milestone 6. Found: `Audio.time()` does not advance with
   `--advance` in headless runs (it's the audio engine's own clock, not the
   simulated timeline) — added `clock.luau`, a zero-size `ScriptedLayout`
   ticking `Economy.gameTime` every frame, as the real clock every other
   script reads. This is the "one invisible driver script" from the
   architecture section below, arriving a few milestones earlier than
   planned because the dig cooldown needed a reliable clock to be
   headlessly testable at all.
   **Follow-up:** the cooldown had no visible feedback, so an on-cooldown
   click looked identical to a broken button. Added a cooldown ring: the
   item now sits in a `layoutTypeValue="stack"` box with a `CooldownRing`
   sibling whose stroke `TrimPath.end` binds to a new
   `Economy.digCooldownFraction` (computed each frame in `clock.luau` from
   `gameTime`/`lastDigTime`/`digSpeedSeconds`, which also moved from
   main.luau's local state onto `Economy` so the clock script could read
   it). Full dark ring right after a dig, unwinding to nothing as it
   becomes clickable again.

**Design/UX pass** (before milestone 4): a full playtest review turned up
11 gaps across game design, UI and UX. All fixed in one pass:
- **Item rarity is now weighted**, not uniform — common items (Bottle Cap,
  Nail, Tin Can) turn up far more than rare ones (Screw, Key, Coin),
  via a weighted-random pick in `main.luau`.
- **Starting dig cooldown lowered 15s → 8s** for snappier early manual
  play (still upgrades down to the original 5s floor). A deliberate
  tuning call, not a bug fix — revisit if it doesn't feel right.
- **Upgrade panels now show real affordability/maxed state**: dimmed
  (`opacity` bound to a computed 1.0/0.4) when currency < $110, and the
  cost label swaps to "MAX" when the stat is capped — both computed each
  frame in `clock.luau` and bound directly, no new listeners needed.
- **Inventory count ("X/12")** next to the strip, via a native
  `DataConverterListToLength` → `DataConverterToString` chain — no
  script needed, and doubles as the "inventory is full" signal.
- **Sell All previews its payout** ("Sell All ($27)") from a new
  `Economy.inventoryValue`, summed every frame in `clock.luau`.
- **Inventory slots show `$` prefix** for consistency with the rest of
  the UI.
- **The item now dims while on cooldown** (`opacity` bound to
  `digCooldownFraction` through a `DataConverterRangeMapper`, 1.0→0.5)
  and **pops on both digging and becoming ready again** (`scaleX`/`scaleY`
  bound to a new `Economy.itemPulseScale`, a decay curve `clock.luau`
  recomputes from a `lastPulseTime` stamped by either event). All fully
  native binds except the two pulse triggers, which are one line each in
  the scripts that already existed.

Confirms the "scripts compute, RML/state-machines interact" split still
holds even for polish: none of this needed a new listener or state
machine — every visual reacts to a number `clock.luau` already owns.

**Follow-up 2** (still before milestone 4):
- **Removed the Auto-Sell panel entirely** rather than leaving it
  purchasable-but-inert — spending $110 on a stat with no behaviour yet
  would read as worse than a bug, it'd read as the game lying. The
  underlying `Economy.autoSellSeconds` stays untouched for milestone 6,
  when the panel (and its actual passive-sell behaviour) comes back
  together.
- **Sell All now dims when the inventory is empty**, the same
  affordable/no-op pattern as the upgrade panels (`Economy.sellAffordable`,
  computed alongside `inventoryValue` in `clock.luau` since both are
  already iterating the list every frame).
- **Added a fading "+$N" popup** on the item after each dig
  (`Economy.digPopupText`/`digPopupAlpha`, a `lastDigPopupTime` stamped
  in `main.luau`, faded over 1s in `clock.luau` the same way the pulse
  decays over 0.25s). Pulled forward from the planned milestone 8 pass
  since the decay-curve pattern already existed and the win was cheap.

**Core loop change** (still before milestone 4): click-to-collect replaced
with always-on auto-collect + click-to-boost — see "Core loop" above for
the reasoning. Mechanically: the actual collect logic (weighted item pick,
`inventory:push`, popup/pulse stamping) moved from `main.luau`'s click
handler into `clock.luau`'s `advance()`, firing whenever
`digSpeed - (gameTime - lastDigTime) <= 0`, then resetting `lastDigTime`
to restart the cycle. `main.luau` (kept the filename; renaming was more
churn than it was worth) now only cuts `CLICK_CUT_FRACTION` (20%) off
whatever time is left — implemented by moving `lastDigTime` *backward*
by `remaining * 0.2`, which took one sign error to get right (moving it
forward means less time has "passed" since the last collect, which
lengthens the remaining time, not shortens it — the opposite of a boost).
Click and auto-collect now use different pulse magnitudes
(`Economy.pulseMagnitude`, set alongside `lastPulseTime` by whichever
event fires) so a boost-click still feels responsive without being
confused for an actual collection. Verified headlessly: 20s with zero
clicks yields exactly 9 items (3 auto-collections × 3 items, matching
the 8s cycle); the same ~8s window with 5 rapid clicks yields 6 items
instead of 3, confirming the boost genuinely pulls forward a second
collection.

**Boost tuning + Elbow Grease upgrade** (still before milestone 4): 20% per
click was reported as feeling wrong once played - front-loaded, since
cutting a percentage of a shrinking `remaining` value means the first
click after a fresh cycle is worth a lot and a click near the end is
worth almost nothing. Fixed by cutting a percentage of the FULL cycle
instead (already the plan from the prior fix, this made it worse at
20% since every click, cheap or not, is a large absolute chunk).
Dropped to 1% and turned it into a fourth upgrade, **Elbow Grease** —
thematically you pitching in yourself alongside the digger, the
"manual click power" idle-game convention. (Named "Pep Talk" briefly
first; renamed once played — "Elbow Grease" reads better.)
`Economy.elbowGreasePercent` starts at 1, steps by 1 per $110 purchase,
caps at 10 (a placeholder ceiling — revisit if maxed-out clicking still
feels too weak). Verified by isolating the click's effect: identical
setup with and without a final click, at Elbow Grease level 2, differs
by exactly 0.021 in `digCooldownFraction` — a real 2%, confirming the
boost scales with the purchased level.

4. ✅ **First bot (Beach Boy)** — purchasable ($458), an additional producer
   of the same kind as the starter item: its own independent auto-collect
   cycle over its 3 item types (Bottle Cap/Nail/Tin Can), its own
   click-boost.

   Generalized the architecture rather than duplicating the starter's
   logic a second time, since Steel Seeker (milestone 5) needs a third
   copy of the same thing regardless: introduced a `Producer` view model
   (producers.rml) holding everything that used to live directly on
   `Economy` — `lastDigTime`, `digCooldownFraction`, `itemPulseScale`,
   `lastPulseTime`, `pulseMagnitude`, `digPopupText`/`digPopupAlpha`/
   `lastDigPopupTime`, plus a new `swatch` colour and `itemPoolName`.
   `Economy.producers` is a `ViewModelPropertyList` of these, rendered via
   an `ArtboardComponentList` exactly like the inventory rows, through a
   new reusable `ProducerWidget` artboard (isComponent, its own internal
   `StateMachine` + click listener) — so the beach area is just "one
   widget per owned producer," starting with one (the free starter) and
   growing as bots are bought. `clock.luau` now iterates the list running
   the identical per-producer cycle for each row, keyed off each
   producer's own `itemPoolName` for which weighted item table to draw
   from (`ITEM_POOLS`, keyed by name). `main.luau`'s click-boost script
   now lives *inside* `ProducerWidget`, reading the row's own bound
   instance via `context:viewModel()` for producer-specific state while
   still reaching `context:globalViewModel('Economy')` for the shared
   upgrades (`digSpeedSeconds`, `elbowGreasePercent`) that apply to every
   producer alike.

   Buying a bot is a `Data.Producer.new(instanceName)` pushed onto
   `Economy.producers` (a new shared `buyBot.luau`, parameterised via
   `ScriptInput*` the same way `upgrade.luau` already was) — no "owned but
   inactive" state to track, a bot simply doesn't exist in the list (and
   its widget doesn't render) until it's bought. The purchase panel dims
   when unaffordable and its cost label swaps to "Owned" once bought,
   same pattern as the upgrade panels.

   Verified clean, inspected with zero wiring problems (across all three
   `.rml` files now compiling as one document). Confirmed headlessly by
   dumping the full `producers` list after buying Beach Boy: two entries
   with completely independent `lastDigTime`/`digCooldownFraction` values
   (proving separate cycles, not a shared one), Beach Boy's `itemPoolName`
   correctly `"beachBoy"` against the starter's `"all"`, and a screenshot
   showing two distinctly-coloured circles side by side in the beach area.

**Roaming producers** (still before milestone 5): producers now wander
the beach area instead of sitting in a fixed flex slot, so they read as
actively out collecting rather than static icons. Each `Producer`
instance gained `roamX`/`roamY` (current position) and
`roamTargetX`/`roamTargetY` (current destination); `clock.luau` drifts
position toward target at `ROAM_SPEED` (40pt/s) each frame and picks a
new random target on arrival. Mechanically this needed
`ProducerWidget`'s own `LayoutComponentStyle` to become
`positionTypeValue="absolute"` with `positionLeft`/`positionTop` bound to
those coordinates — pulling each row out of the `ArtboardComponentList`'s
flex flow so it can be positioned freely rather than laid out beside its
siblings. Bounds are a conservative fixed box (20–520 × 20–320) rather
than the beach area's real resolved size, since a script has no generic
way to read an arbitrary sibling's computed layout size; noted as a
placeholder to revisit in the milestone 9 responsive-layout pass, since
at wider viewports the roam area won't use the full beach width.

Verified clean, inspected with zero wiring problems. Confirmed with
screenshots at t=0/5s/10s that a producer visibly moves across the beach
area over time, and numerically that clicking a producer at its
*current* roamed position (computed from `roamX`/`roamY`, not its
original slot) still correctly applies Elbow Grease — proving hit-testing
tracks the live rendered position, not an authored one. Confirmed two
owned producers roam independently without converging or overlapping
persistently.

**Balancing pass** (still before milestone 5): replaced the flat $110-per-
level upgrade cost with the standard incremental-game curve,
`Cost(n) = base × growth^n` (Cookie Clicker uses growth≈1.15 for frequent
small purchases; ours needed to be much steeper since each upgrade only
has 5 levels total, not dozens). Also re-leveled all three upgrades to
the same 5 uniform steps each, since they'd drifted wildly uneven
(Items/Dig 5 levels, Elbow Grease 9, Dig Speed **28** — which would have
made "all three maxed" an incoherent target):
- Items/Dig: 1→2→3→4→5→6 (unchanged shape)
- Dig Speed: 60→49→38→27→16→5 (step widened from −2 to −11)
- Elbow Grease: 1→2→3→4→5→6% (cap lowered from 10 to 6)

`upgrade.luau` derives which level you're buying from the stat's current
value rather than storing it separately (`n = |current − start| / |step|`,
where `start` is `minValue` for an increasing stat or `maxValue` for a
decreasing one) — one fewer piece of state to keep in sync.
`clock.luau`'s cost-label/affordability logic mirrors the identical
formula for display, reading the same constants.

Landed on **base $5, growth 2.8** after empirically simulating real
play rather than solving for it on paper — the compounding feedback
loop (buying an upgrade increases income, which changes how fast you
afford the *next* one) makes closed-form timing genuinely hard to get
right by hand. Simulated via the same `--advance`/`--pointer`/
`--data-dump-every` harness used throughout this build: a script
auto-clicks Sell All and all four purchase buttons every 10 simulated
seconds (a "light passive" playstyle, deliberately not chasing the
roaming item, since that's the harder-to-automate and less essential
income source) and samples the full state every 2s. Iterated growth
from 1.8 up through 3.5 before landing on 2.8, which across three
independent trials gave: first upgrade purchase at 12s (when the first
item rolled is worth ≥$5, roughly 70% of outcomes) or 64s (on the 30%
chance the first roll is a $1 Bottle Cap, which needs a second
collection cycle to clear even a $5 cost — a hard floor from the item
value distribution itself, not something cost-tuning alone can fix) —
both a reasonable reading of "starts out quick." All three upgrades
maxed at 660–732s (11–12.2 min) across the three trials, comfortably
inside the 10–15 minute target, with Beach Boy's unrelated flat $458
cost landing at a coherent ~12.5 min in the same trajectory.

Verified clean, inspected with zero wiring problems.

**Per-robot onboard storage** — a thematic-alignment pass. The player's
stated vision: robots suck items into their *own* onboard storage; the
player empties and sells that storage; upgrades make them collect more,
faster, and (via a manual click) harder. The shared `Economy.inventory`
list didn't fit that — it made "inventory" an abstract account-wide
pool with no visible connection to which robot dug up what, and gave
no reason for a robot to ever stop. Replaced with:

- Each `Producer` instance now owns `storageCapacity` (3, for both
  bots), its own `storage` list (was `Economy.inventory`, shared), and
  a computed `storageLabel` string.
- `clock.luau`'s auto-collect loop checks `storage.length <
  storageCapacity` before collecting; once full, the cycle freezes
  (`digCooldownFraction` pinned at 0, `lastDigTime` left untouched)
  rather than resetting, so a full robot visibly stops instead of
  silently discarding what it finds. Reusing `lastDigTime` this way
  means the moment the robot is emptied it resumes exactly where the
  cycle would have been, immediate collection included if a cycle had
  already elapsed while blocked.
- A small on-stage badge (a dark pill in the widget's corner, bound to
  `storageLabel`) shows `"n/3"` while there's room and switches to
  `"!"` at capacity — the "needs attention" signal the player asked
  for, with no separate UI to toggle between robots.
- `main.luau`'s click handler now branches on that same fill check:
  room left still boosts (Elbow Grease, unchanged); full instead sums
  and clears *that robot's own* storage into currency on the spot —
  "clicking a full robot sells it" was the player's own proposed
  resolution to "how do you tell robots apart in the UI," and needs no
  additional listener or state, since the widget already owns a click
  handler.
- `sell.luau` (Sell All) generalizes the same way: iterates every
  producer's storage and sums+clears each into currency in one pass,
  so it stays a fleet-wide convenience layered on top of, not a
  replacement for, the per-robot mechanic.
- The bottom strip stopped being "the" inventory (it rendered
  `ItemSlot` rows off one shared list) and became a fleet-wide
  aggregate instead: "Stored: `<n>` (`$<value>`)", summed each frame
  across every producer's storage. The now-unused `ItemSlot` artboard
  and its `ComponentAsset` (items.rml) were dead code once nothing
  rendered per-item icons any more, so removed; `Item` (the view model
  + its 6 named instances) stayed, since `Data.Item.new(...)` still
  creates them every collect.

Building the badge surfaced a genuine gotcha, not a design bug: **the
first sibling in markup draws on top** (`rive docs transforms`) — the
opposite of HTML/SVG stacking. The badge's label text was invisible
behind its own background pill until reordered (label declared first,
pill second); every other stack in this project (the digging circle
itself) happened to already read correctly-if-accidentally because its
top layer (`DigPopup`) is translucent enough to blend through even
when technically behind. Verified via a temporary `ROAM_SPEED = 0`
edit (roaming uses real, unseeded randomness, so a screenshot's pixel
coordinates for a wandering bot can't be replayed against a second
headless run) to click a known, fixed position: confirmed storage
fills to 3 and freezes (`digCooldownFraction` pinned at 0,
`storageLabel` reading `"!"`), a click on a full robot clears just its
own storage into currency, and Sell All still sums and clears every
producer's storage in one pass. `ROAM_SPEED` restored afterward.
Verified clean, inspected with zero wiring problems.

**Storage capacity upgrade** — a fourth upgrade, "Capacity", buyable
from the side panel: 3 → 8 in 5 steps (same shared Cost(n) = base *
growth^n curve, base $5 growth 2.8, as the other three), raising every
robot's `storageCapacity` at once rather than per-robot. It's a shared
`Economy.storageCapacity` stat - the same shape as `digSpeedSeconds`,
`itemsPerDig` and `elbowGreasePercent` - but each `Producer` instance
still carries its own mirrored `storageCapacity` field too (kept from
the per-robot-storage work, since `storageLabel` and `main.luau`'s
full-click check both read it locally off the row). `clock.luau` is
the sole writer of that mirrored field now, syncing every producer's
copy from the shared stat every frame, so newly-purchased bots pick up
whatever level has already been bought with no special-casing in
`buyBot.luau`. Verified headlessly: bought the upgrade after a Sell
All (currency was needed first), capacity went 3→4 on the shared stat
and on the Starter's own mirrored copy in the same frame, and the
robot's badge read the new "n/4" immediately.

**Repeatable Beach Boy purchase, cheaper entry price** — Beach Boy was
a one-time $458 flag-gated purchase; changed to a repeatable buy at a
much lower $150 entry, each subsequent one pricier on its own Cost(n)
= base * growth^n curve (growth 1.6 - steeper than the $5-base stat
upgrades' 2.8, since each purchase here is a whole extra producer, not
a shared incremental stat). $150 was chosen as roughly "the first
Beach Boy should feel reachable a little after the three cheap
upgrades are within reach, not as a distant end-of-run goal" - the old
$458 had been tuned as a one-off milestone, which stops making sense
once it's the first rung of an open-ended ladder.
`Economy.beachBoyOwned` (a 0/1 flag) became `beachBoyCount` (how many
owned); `buyBot.luau` dropped its owned-flag gate for a count-based
cost curve (mirroring `upgrade.luau`'s shape, parameterised so the
same script still backs Steel Seeker later), and now applies a small
random jitter to a newly-spawned producer's roam position/target -
without it, every copy of the same bot would spawn stacked exactly on
the template's fixed position until roaming happened to separate them.
The panel label now reads "Beach Boy ×`<count>`" instead of toggling
to "Owned". Verified headlessly: bought one at $150 (count 0→1, next
price 150→240, matching 150*1.6 exactly), confirmed a second
`ProducerRows` entry appeared with the Beach Boy item pool and a
position jittered off the template's fixed spawn point, and screenshot
-confirmed two producers on stage with the panel reading "Beach Boy
×1" at the new $240 price.

**Wheel tracks** — a small fading mark now drops behind every roaming
producer, the "nice to have" from the vision-alignment pass ("some
robot wheel tracks so we can see where the robot has driven"). New
file `trails.rml` holds a `TrackPoint` view model (`x`, `y`, `alpha`,
`spawnTime`) and a `TrackDot` component artboard (a small flattened
oval, absolute-positioned by `x`/`y` the same way `ProducerWidget`
positions itself by `roamX`/`roamY`, opacity bound to `alpha`) - one
shared `Economy.trail` list rather than a list-per-producer, since a
dropped mark doesn't need to remember which robot left it, just where
it is; a second `ArtboardComponentList` ("TrailDots") renders it,
declared *after* `ProducerRows` in `scene.rml` so tracks draw behind
the robots (draw order is front-to-back by declaration - the first
sibling is on top - the reverse of HTML/SVG, per `rive docs
transforms`, and already a gotcha once this build over the storage
badge).

Each `Producer` gained `lastTrailX`/`lastTrailY`, the position its
last mark was dropped at; `clock.luau` compares that to the producer's
current `roamX`/`roamY` every frame and, once the distance clears
`TRAIL_DROP_DISTANCE` (18pt), pushes a new `TrackPoint` and moves
`lastTrailX`/`Y` up to the current position - distance-based rather
than time-based, so marks space out evenly along the path regardless
of how fast the producer happens to be moving. A separate pass fades
every point in the shared list linearly over `TRAIL_FADE_DURATION` (3s)
from its own `spawnTime`, and the list is capped at `TRAIL_MAX_COUNT`
(40, shared across every producer) by dropping the oldest
(`:shift()`) whenever a push goes over - the cap, not the fade, is
what actually bounds memory over a long idle session, since a
fully-faded mark is invisible but still sitting in the list until
something newer pushes it out.

Verified headlessly: screenshotted a producer mid-roam at both 20s and
60s of simulated time and saw a short trail of shrinking-opacity dots
following it in both; `--data-dump` on the `trail` list after 60s
confirmed it holds exactly 40 items, proving the cap engages rather
than growing unbounded. Verified clean, inspected with zero wiring
problems.

**Universal tooltip architecture, applied to Elbow Grease** — built as
reusable infrastructure first, per explicit direction, rather than a
one-off bubble on the robot. One shared subsystem: a global `Tooltip`
view model (`text`, `visible`, `x`, `y`) and a single overlay
(`scene.rml`, declared as the root artboard's *first* child so it
draws on top of everything - draw order is front-to-back by
declaration, the same gotcha the storage badge hit) that any feature
can retext and reposition. Two shared scripts,
`showTooltip.luau`/`hideTooltip.luau`, do the retexting: wiring a
tooltip onto anything is two `StateMachineListenerSingle` entries
(`enter`/`exit`) plus a `text`/`anchorX`/`anchorY` input on the enter
one - no new script logic per feature, matching the same
"parameterise one shared script via `ScriptInput*`" shape as
`upgrade.luau`/`buyBot.luau`.

The one real design problem: a tooltip needs a screen position, but
the *host* differs per feature - a static side panel's position is
fixed at author time, while a producer's position changes every frame
as it roams. `showTooltip.luau` resolves this once, generically,
instead of pushing the problem onto every caller: it checks whether
its own host's view model exposes `roamX`/`roamY` (`context:viewModel()`
- the same lookup `main.luau` already uses to read "this row's own
producer"); if so, that becomes the tooltip's base position (converted
from BeachArea-local into root-artboard coordinates via two fixed
offsets - `PRODUCER_WIDGET_CENTER` and `BEACH_AREA_ROOT_Y`, both
already known from the roaming/badge work), and `anchorX`/`anchorY`
apply as a small offset on top (e.g. "70pt above it"); if not (a
static panel with no such properties), base is `(0, 0)` and
`anchorX`/`anchorY` become plain root coordinates. One code path
covers both a fixed element and a moving one with no per-caller
branching.

Applied to Elbow Grease exactly as the player asked when reviewing the
game's thematic fit ("give it a tooltip that will help explain that by
clicking on the robot, you are helping it to speed up it's collection
of items"): the robot's own clickable circle (already wired for the
Boost click listener in `producers.rml`) gained matching `enter`/`exit`
listeners reading "Click me to speed up my digging!". Verified
headlessly (with a temporary `ROAM_SPEED = 0`, the same trick used to
test the storage badge, so a hover coordinate stays valid across the
build): a `move` pointer event onto the robot set `Tooltip.visible` to
1 with the right text and a position matching the robot's actual
on-screen centre minus the 70pt offset; moving away set `visible` back
to 0; a screenshot confirmed the bubble renders above every other
layer. Confirmed the new hover listeners don't interfere with the
existing click-to-boost listener on the same target. Verified clean,
inspected with zero wiring problems.

5. **Second bot (Steel Seeker)** ✅ — a third producer type (Starter and
   Beach Boy came first), proving the Producer/ProducerWidget/buyBot.luau
   architecture generalizes to N bot types with zero new script logic,
   exactly as it was built to. Repeatable purchase at $220, growth 1.6
   (same shape as Beach Boy, pricier entry since its pool skews to
   higher-value finds), with its own `steelSeekerCount`/
   `steelSeekerAffordable`/`steelSeekerCostLabel` Economy stats and a
   `BuySteelSeekerPanel` mirroring `BuyBeachBoyPanel` exactly. Its own
   `steel-gray` swatch and roam start (250, 250, away from both other
   spawn points) so three producers don't all launch stacked. New
   `steelSeeker` item pool in `clock.luau` (`ITEM_POOLS`) - Screw, Key,
   Coin only, deliberately excluding the cheap BottleCap/Nail/TinCan
   that both `all` and `beachBoy` draw from, so buying one is a genuine
   upgrade to average find value, not just more of the same. No new
   widget, click, tooltip or wheel-track code was needed - Steel Seeker
   is just another named instance of the existing `Producer` view model
   and `ProducerWidget` component, rendered through the same
   `ArtboardComponentList` the other two already use.

   Verified headlessly: bought one after grinding currency via repeated
   Sell-All cycles (confirmed cost climbed $220→$352, matching
   `220*1.6` exactly); screenshot showed the new steel-gray robot on
   stage with its own storage badge and the panel reading
   "Steel Seeker ×1"; a 600s `--data-dump-every` trace of both
   producers' `storage` lists confirmed Steel Seeker collected only
   Screw/Key/Coin and the Starter (on the `all` pool) collected the
   full six-item spread including Key/Coin/Screw but also
   BottleCap/Nail/TinCan - no cross-contamination in either direction.
   Confirmed hovering a Steel Seeker also raises the shared tooltip
   (proving the universal tooltip and the Producer architecture compose
   for free, with no bot-specific wiring). Verified clean, inspected
   with zero wiring problems.

6. **Auto-sell** ✅ — replaced with the docking mechanic the player
   originally floated during the vision-alignment pass ("a robot
   travels to a docking station and automatically sells its goods
   there"), after a first pass built a fleet-wide *timer* instead
   (fire every N seconds regardless of what any robot was doing). The
   player asked for the timer to be swapped out for this once it was
   in place: a fixed `DockBox` at the bottom-center of the beach area
   (same coordinate space `roamX`/`roamY` already use, so no coordinate
   conversion needed); once full, a producer beelines for it instead of
   picking another random roam target, and sells the moment it arrives
   - automatic, but tied to *movement*, not a clock.

   Gated behind a purchase rather than available from the start, at the
   player's explicit request: `Economy.dockSpeed` starts at 0
   ("locked" - a full robot just freezes, exactly as it did before this
   milestone existed, manual click still the only way to empty it). The
   first purchase moves it off zero, which *simultaneously* unlocks
   docking and sets the dock-seeking speed; further purchases only make
   the trip faster (same shared Cost(n) curve as every other upgrade,
   0→100 over 5 steps of 20). One side panel slot serves both states,
   because they're the same stat: `dockSpeedLabel` is a single computed
   string, "Auto-Sell" while locked, "Robot Speed `<n>`" once bought,
   swapped by `clock.luau` rather than two panels toggled by
   visibility. Ambient wandering was deliberately left on the existing
   fixed `ROAM_SPEED` throughout - only a *full* robot's behaviour
   changes with `dockSpeed`, so nothing stands still just because
   docking hasn't been bought yet (a real alternative that was
   considered and explicitly ruled out before building, since it would
   have changed the game's very-first-launch feel).

   `clock.luau`'s roaming block now branches per producer: full AND
   `dockSpeed > 0` means the roam target becomes the dock's fixed
   position and the step uses `dockSpeed` instead of `ROAM_SPEED`;
   arrival (within a threshold) sums and clears that producer's own
   storage into `currency` - the same sum+clear shape as a manual
   full-click sale in `main.luau`, which stays available throughout (the
   player's choice: wait for the walk, or click for an instant sale).
   Reused the existing pulse/popup feedback fields for a "SOLD +$n"
   popup on arrival, same as the manual version.

   Verified headlessly: confirmed a full robot keeps wandering normally
   (never approaching the dock's coordinates) for as long as `dockSpeed`
   stays 0; bought the first level and watched, via a
   `--data-dump-every` trace, `roamX`/`roamY` visibly converge on the
   dock's position once the robot filled up, `storageLabel` flip from
   `"!"` to `"0/3"` on arrival, and `currency` jump by exactly the sold
   total in the same tick; confirmed manual click-to-sell still empties
   a robot mid-walk; screenshotted both states of the panel ("Auto-Sell"
   locked/dimmed dock vs. "Robot Speed 20" with the dock at full
   opacity). Verified clean, inspected with zero wiring problems.

   **Bug fix (playtesting):** emptying a robot mid-walk correctly
   cleared its storage, but left `roamTargetX`/`roamTargetY` still
   pointing at the dock - so it kept walking there anyway, just at
   ordinary `ROAM_SPEED` instead of `dockSpeed`, since nothing had told
   it to pick a new direction. The original verification checked that
   the *sale* happened, not that the *target* changed, so this slipped
   through. Fixed in `clock.luau`'s roaming block: when a producer
   isn't docking (no longer full) but its current roam target still
   exactly equals the dock's fixed coordinates, it immediately rerolls
   a fresh random target rather than waiting to arrive - this covers
   emptying it any way (a manual click, or Sell All), since the check
   is purely "target == dock, but not full" rather than tied to which
   script did the selling. Verified headlessly (with the same
   temporary seeded-PRNG technique used for the demo GIF, reverted
   after): traced a producer's exact walk to the dock, clicked it
   mid-route to sell manually, and confirmed in the same tick its
   `roamTargetX`/`Y` jumped away from the dock's coordinates to a new
   random point, then confirmed five simulated seconds later it had
   moved toward that new point rather than back toward the dock.
   Verified clean, inspected with zero wiring problems.

**UI/UX polish pass (playtesting round 2)** — the first of a batch of six
notes, ordered so the big architectural one (per-class upgrades + tabs +
Steel Seeker discovery, not yet started) doesn't force rework of things
built before it.

- **Wheel-track/badge layer order fix.** The wheel tracks were rendering
  *above* the robot body instead of behind it - confirmed by screenshot,
  not assumed from docs, since it turned out `ArtboardComponentList`-
  generated rows draw in the OPPOSITE order from the general "first
  sibling draws on top" rule that plain shapes in one artboard follow
  (verified both ways empirically: swapping `TrailDots`/`ProducerRows`
  declaration order in `scene.rml` fixed the trail, while the *existing*
  correct rule - first declared, drawn on top - is what already made
  `BadgeLabel` sit on `BadgeBg` and now also puts the whole `BadgeAnchor`
  on top of the robot's own `Stack` after swapping their order too).
  Final stack, back to front: background, trail, cooldown ring, robot
  body, popup, badge, tooltip. Verified via before/after screenshots
  (cropped/zoomed on an overlapping trail dot) showing it now correctly
  hidden behind the robot except where the trail extends past it.

- **Tutorial tooltip: smaller, and one-time instead of hover-spam.** The
  robot's tooltip bubble was judged too large/intrusive on hover. Shrank
  it (smaller font/padding) and shortened the copy ("Click to dig
  faster!"), but the bigger change is behavioral: it now auto-shows over
  the first producer from the very start of the game - no hover needed -
  and disappears for good the first time the player clicks *any* robot
  (`Economy.elbowGreaseTaught`, flipped once in `main.luau` regardless of
  which click branch fires). `clock.luau` forces the shared `Tooltip`
  overlay onto the first producer's position every frame while
  untaught; the moment the flag flips, it stops touching `Tooltip` at
  all and hands control back to the ordinary hover-driven
  `showTooltip.luau`/`hideTooltip.luau`, which still works afterward as
  an opt-in reminder. Verified headlessly: tooltip visible at frame 1
  with no hover; a single click flips the flag and it stays hidden 30
  simulated seconds later even off-hover; hovering the robot again after
  being taught still shows it normally (opt-in, not forced).

Still to come from this same playtesting round, not yet started:
- **Upgrade-panel tooltips** - hover explanations on all seven side-panel
  buttons, deliberately sequenced *after* the tabbed restructure below so
  they're wired onto the final panel layout, not thrown away.
- **Per-class upgrades + tabbed UI + Steel Seeker discovery** - the big
  one. Each robot class (Starter/Beach Boy/Steel Seeker) gets its own
  independent `itemsPerDig`/`digSpeedSeconds`/`elbowGreasePercent`/
  `storageCapacity` instead of one shared set (a new `RobotClass` view
  model, mirroring how `Producer` already works, with `Producer` gaining
  a class reference); a tab bar per class plus a "Robots" tab for
  purchases; Steel Seeker starts hidden until some unlock condition
  (still to be decided) fires. Blocked on three open questions before
  starting: whether Starter gets its own tab or shares Beach Boy's,
  what specifically unlocks Steel Seeker, and whether Robot Speed
  (the dock upgrade) stays one fleet-wide stat or also goes per-class.
- **Bento-style stats dashboard** - a later, larger view of full
  lifetime/fleet statistics once unlocked. Explicitly scoped as a
  future milestone, not part of this pass - added here as a placeholder
  only, no design work done yet.

7. **Persistence** — host page saves/loads `Economy` to `localStorage`;
   reload the page mid-game and confirm state survives.
8. **Visual feedback pass** — floating "+N" numbers on collect/sell, button
   press feedback, bot-purchase feedback animation.
9. **Responsive layout pass** — verify the layout holds up from narrow
   laptop width to ultra-wide, horizontally only.
10. **Ship** — HTML host page using the Rive web runtime pointed at the
    signed build, published both via `rive --publish=web` and to GitHub
    Pages from this repo.

Later milestones (post-v1, not yet scheduled): remaining 2 bots + items,
achievements, tooltips polish pass, `rive push`/`rive pull` handoff for a
manual art pass in the Editor, offline/away earnings, portrait layout,
bento-style full-fleet stats dashboard (unlocked view of lifetime/fleet
statistics).

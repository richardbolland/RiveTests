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

5. **Second bot (Steel Seeker)** — same pattern, different item pool; verify
   bots never cross-collect each other's items.
6. **Auto-sell** — driver script sells inventory automatically on the
   upgradeable timer; visible countdown in UI.
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
manual art pass in the Editor, offline/away earnings, portrait layout.

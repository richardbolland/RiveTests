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

Click beach → spawn 1 item (upgradeable) at author-chosen values → item lands
in inventory (12 slots) → sell manually or via auto-sell timer → currency
increases → spend on upgrades/bots → owned bots auto-collect their specialised
items on their own timer, no click needed.

## Rive architecture

- **One global View Model (`Economy`)**: currency, itemsPerDig, digSpeedSeconds,
  autoSellSeconds, and nested instances/lists for inventory slots, owned bot
  counts, and upgrade levels. Everything on screen binds to this — no manual UI
  refresh code.
- **One invisible driver script** (`ScriptedLayout`, zero size, attached once):
  owns `advance(self, seconds)`. Ticks the dig cooldown, each owned bot's
  collection timer, and the auto-sell countdown; on each timer firing it picks
  a weighted-random item for that source and writes into the `Economy` view
  model via `context:globalViewModel("Economy")`. This is the only Luau in the
  project for v1 — everything else stays in RML/state machines per the
  scripts-are-for-computation, not-interfaces rule in the CLI docs.
- **Inventory & bot-shop rows**: Rive `List` component bound to view-model
  arrays, not hand-placed instances — matches how the achievement/inventory
  grids would need to scale later.
- **Beach items**: a small reusable artboard/component per item type, spawned
  dynamically (not hand-placed), driven by state-machine input for the
  collect-on-click reaction (scale/fade out) rather than bespoke script hit
  testing.
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
4. **First bot (Beach Boy)** — purchasable, driver script auto-collects
   Beach Boy's 3 item types into inventory on its own timer, independent of
   clicking.
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

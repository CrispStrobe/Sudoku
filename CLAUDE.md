# CrispSudoku — working notes

Conventions and traps for anyone (human or agent) changing this codebase.
Architecture lives in `README.md`; this is the shorter, sharper list of things
that have actually gone wrong here.

## Layout: never branch on one axis

Every layout bug this project has shipped was the same mistake — **a decision
made from one dimension of a two-dimensional box**:

| What was read | What broke |
|---|---|
| `maxGridSize` capped at 320 by device *width* | the board got half a 320pt screen and could not use the slack around it |
| cell font from an `isTablet` flag derived from *width* | 9x9 digits clipped on a short viewport |
| `isTablet = size.width > 600` | a 653x280 folded Fold was called a tablet and its number pad collapsed to 5pt |
| `AspectRatio(1)` inside a vertical scroll view | the explain board took its *width* as its height: 420pt of board in a 190pt window |
| pad tile font with a `.clamp(12, 28)` floor | digits wider than the tile that had to hold them |
| pencil-mark font with a `.clamp(6, 12)` floor | same, one grid size smaller |

So, when you write a layout:

- **Consult both axes.** A square sized `min(maxWidth, maxHeight)`, not
  `maxWidth`. `LayoutBuilder`'s own constraints, not `MediaQuery.size` — they
  differ wherever a parent has already clamped you.
- **Classify a device by `shortestSide`, not `width`.** A phone turned sideways
  is still a phone. That is what `shortestSide` is for.
- **A clamp floor is not a favour.** If the box is genuinely 5pt wide, a 6pt
  minimum guarantees overflow. Size from the box and let
  `FittedBox(fit: BoxFit.scaleDown)` be the backstop.
- **Beware unbounded constraints.** A vertical `SingleChildScrollView` offers
  infinite height, so anything that sizes itself from its constraints will size
  itself from width alone in there.
- If you do branch on a dimension, say in a comment *which axis and why*.

New layout work needs a case in `test/board_layout_test.dart`. The device list
there is deliberately the awkward ones — a folded Fold in both orientations, a
Surface Duo, an iPhone SE — because the comfortable sizes never find anything.

## The web is a different runtime, not just a different screen

`flutter test` runs on the Dart VM. `flutter build web` compiles but does not
*run*. Under dart2js `int` is a JS double and `Uint64List` cannot be allocated
at all — which is how a crash in the CSP solver shipped in v1.1.0 with the whole
suite green, every Killer generation throwing in the browser, and the screen
quietly serving a cage-less classic board instead.

- `tool/web_killer_probe.dart` compiles the real generator with dart2js and runs
  it. CI runs it on every push. If you touch `variant_engine.dart` or bump
  `dart_csp`, run it.
- A bundled asset declared as `assets/x.json` is served at
  **`/assets/assets/x.json`** — the doubled segment is Flutter's asset root.

## Some names are persisted

`SudokuVariant`, `GridSize`, `GridShape` and `SudokuDifficulty` are written to
disk by `.name` (the resume slot in `saved_game.dart`, the counters in
`stats.json`) and read back with `values.byName`. Renaming a value is a data
migration, not a refactor: it invalidates every saved game and silently resets
achievement progress, with no compile error.

`SudokuVariant.x` is the standing temptation — the accessors beside it are
already called `diagonal`/`isDiagonal`, so tidying it up looks free. It is not.
`test/persisted_names_test.dart` pins the lot.

## Never let a variant degrade silently

If Killer generation fails, the screen reports the failure. It used to fall back
to a classic board while `isKiller` stayed true, so the player got a cage-less
grid with the hint and explain buttons mysteriously disabled — a thing that
looks like a working game and is not the one they asked for. That is what hid
the dart2js crash for a whole release. `test/killer_no_silent_fallback_test.dart`
pins it.

## Generation cost is not uniform

Proving a Killer puzzle uniquely solvable is a CSP search with no useful upper
bound: generating the bundled 9x9 expert boards took between 2.7s and **474s**
each. Never put that on the main thread — on the web there is no
`Isolate.spawn`, so it *is* the main thread. Boards come from
`assets/killer_puzzles.json`; the live generator is a bounded fallback.

## What each layer of testing actually covers

| Layer | Runs on | Catches |
|---|---|---|
| `flutter test` | Dart VM | logic, layout geometry, widget behaviour |
| `flutter test --tags golden` | Dart VM | layout regressions nobody predicted — opt-in, see `dart_test.yaml` |
| `tool/web_killer_probe.dart` | dart2js in node | engine code that cannot run on the web |
| `integration_test/web_smoke_test.dart` | Chrome via `flutter drive` | the app's own widgets under dart2js |
| `.github/scripts/render_check.js` | Chrome against the deployment | a build that serves every byte and draws nothing |

The first line is the only one that runs by default. The rest exist because
each of the others has already let something through: a green `flutter test`
plus a green `flutter build web` shipped a Killer mode that threw on every
generation in a browser.

Goldens are generated locally and are toolchain-specific; CI runs
`flutter test --exclude-tags golden`. Regenerate with
`flutter test --tags golden --update-goldens` and look at the images.

`debugParticleSeed` exists so goldens are reproducible — the particle layer is
otherwise random, and a seeded RNG plus `ambient: false` is what makes a
rendered frame the same twice.

## Deploys

- **Vercel** — the `Vercel` workflow, on every push to main; PRs get a preview.
  `./deploy.sh` is for a non-main branch or a `--wasm` build.
- **GitHub Pages** — the `Pages` workflow, on a `v*` tag only.
- Release artifacts for six platforms — the `Release` workflow, on a `v*` tag.

Keep `FLUTTER_VERSION` in step across `ci.yml`, `release.yml`, `pages.yml`,
`ios-release.yml` and `vercel.yml`; `dart format --set-exit-if-changed` is only
reproducible against one formatter version.

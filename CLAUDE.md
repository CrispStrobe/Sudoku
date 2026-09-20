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

## Adding a variant

Thermo is the worked example; copy it. A variant is a constraint, and the
pipeline around it already exists:

1. **Model** in `variant_engine.dart` — the clue type, `hasError` (is it wrong
   *yet*), `isSatisfied` (is it complete), and `toJson`/`fromJson` with hard
   validation, because the bundle is the only thing between a bad board and a
   player.
2. **Constraint** — one `Problem` builder plus a `…HasUniqueSolution`. Thermo's
   whole rule is `addStrictlyAscending` per line. `dart_csp` also has
   `addExactSum` (Arrow, Sandwich), `addInSet` (Odd/Even), `addLinearEquals`
   (Kropki) and `addStringConstraint` (Anti-Knight).
3. **Generator** — see the two-phase note in the README. Shapes first for a
   no-givens board, solution-first as the guaranteed fallback.
4. **Painter** in `painters.dart`, scaled to the cell (never a constant).
5. **Enum value** — *append* to `SudokuVariant`, never rename, and add it to
   `test/persisted_names_test.dart`.
6. **Screen wiring** — `isThermo`, the generation branch, win condition,
   conflict highlight, and `hasUnmodelledRules` if the technique solver cannot
   reason about it (hints and explain must then be off, as for Killer).
7. **Bundle** — `tool/generate_…_puzzles.dart` and a loader, if generation is
   slow enough to matter. It is, for anything using the CSP.
8. **Tests** — the rule's edge cases, generator invariants, JSON rejection of
   corrupt input, a bundle validity test, and a no-silent-fallback guard.

KenKen is the worked example of a variant that *removes* a rule: it has no
boxes. Rather than special-case "no regions" through the engine, the saved-game
schema and the painter, its `regions` are the row indices — the region rule
then restates the row rule and is a no-op — plus a `latin` flag on
`SudokuGridPainter` so only the outer edge is drawn heavy. If you add a variant
with an unusual region structure, copy that instead of adding a null.

Thermo's `hasError` is the part worth reading twice: a gap between two filled
cells still constrains them, because each step along the line must add at least
one. `[_, 5, _, 3]` is already wrong.

## Generation cost is not uniform

Proving a puzzle uniquely solvable is a CSP search with no useful upper bound.
The bundled 9x9 expert Killer boards took between 2.7s and **474s** each. KenKen
is normally two orders of magnitude cheaper — most boards land in tens of
milliseconds — and still produced an 80s outlier at 9x9 expert, which is the
whole argument for bundling: the *median* cost is not the number that matters.

Never put that on the main thread — on the web there is no `Isolate.spawn`, so
it *is* the main thread. Boards come from `assets/killer_puzzles.json`,
`assets/thermo_puzzles.json` and `assets/kenken_puzzles.json`; the live
generators are bounded fallbacks.

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

The deploy render check plays a KenKen board as well as the Daily Challenge,
because a variant can break in ways a classic board cannot show: its bundle
missing from the deployment, or its generator throwing under dart2js. That pass
drives the app through Flutter's accessibility tree, which is off until the
hidden `flt-semantics-placeholder` is clicked — and note the widgets then carry
their label in `textContent`, not in `aria-label`, which stays empty. The
variant chips have no text at all and surface as checkboxes in declaration
order, so the pass picks the last one and then *asserts the game screen says
KenKen*: a classic board rendering under the KenKen label still fills 44% of
the screen, so the pixel check alone would pass it.

Goldens are generated locally and are toolchain-specific; CI runs
`flutter test --exclude-tags golden`. Regenerate with
`flutter test --tags golden --update-goldens` and look at the images.

`debugParticleSeed` exists so goldens are reproducible — the particle layer is
otherwise random, and a seeded RNG plus `ambient: false` is what makes a
rendered frame the same twice.

## App Store screenshots

Rendered on a Linux runner, not a simulator: `test/store_screenshots_test.dart`
draws the real screens at exact store pixel sizes as a widget test. Run it with
`bash tool/capture_store_screenshots.sh`, or the `App Store screenshots`
workflow (which also uploads, on request).

Five things had to be true before the images looked like the app rather than a
test render, and each one is a trap worth knowing:

- **Real fonts.** Register them with `FontLoader`, including under the name the
  framework resolves a *null* `fontFamily` to — a `TextPainter` built by a
  painter never sees the theme. The Killer cage sums came out as filled boxes
  until `KillerCagePainter` was given the theme's family explicitly.
- **`debugDisableShadows = false`.** `flutter_test` disables shadows, which
  draws every elevation as a hard black rectangle.
- **An emoji font.** The UI uses emoji; without one they are tofu.
- **`GameStats.debugMode = false`.** `kDebugMode` is true under `flutter test`,
  so the admin panel would otherwise appear in the shop window.
- **Reset framework debug variables inside the test body**, not in
  `addTearDown`: the binding asserts they are back to default when the body
  returns, and a teardown runs after that.

`Future.delayed` in a widget test outside `runAsync` never completes — use
`tester.pump`. That one cost nine minutes of hang.

## App Store submission

The `v*` tag uploads a signed build; it does **not** submit anything. Creating
an App Store version and submitting it is separate, and easy to forget: v1.1.0
through v1.3.0 each uploaded a build that then sat in TestFlight while the
public listing stayed on 1.0.3.

That gap is closed: `tool/asc_release.py` creates the version, attaches the
build, pushes every storefront's listing from `fastlane/metadata/<locale>/` and
can submit. It runs from the `App Store release` workflow, automatically after
a successful tag upload — but stops at "ready to submit" unless dispatched with
`submit=true`, because starting Apple's review should be a decision and not a
side effect of a git tag.

The listing lives in `fastlane/metadata/`, the conventional layout, and is the
source of truth: edit it there, not in App Store Connect, or the next release
overwrites you. `tool/check_store_metadata.py` catches a field over its limit
before the submission does — Apple counts characters, not bytes, which matters
in German.

Nothing on a version in review can be edited. To change anything, cancel the
review submission first (the version returns to `DEVELOPER_REJECTED`, which is
editable), change it, then resubmit. `asc_release.py` and `asc_screenshots.py`
both refuse to touch a version that is not in an editable state rather than
failing halfway through.

The full background, including the API-key setup and the pieces that are
genuinely browser-only (creating the app record, the App Privacy answers), is
`/mnt/volume1/appstore.md` on the build host.

## Deploys

- **Vercel** — the `Vercel` workflow, on every push to main; PRs get a preview.
  `./deploy.sh` is for a non-main branch or a `--wasm` build.
  Commits that cannot reach the browser — docs, tests, `tool/`, `.github/`,
  the non-web platform directories — are skipped via `paths-ignore`, because
  the free plan allows 100 deployments a day and that cap has been hit. A
  commit touching both ignored and non-ignored files still deploys. Since
  `.github/**` is ignored, a change to `render_check.js` does not exercise it:
  dispatch the workflow by hand to force a deploy.
- **GitHub Pages** — the `Pages` workflow, on a `v*` tag, or dispatched
  manually. Because it tracks *tags*, work merged to main is not on Pages until
  the next release: KenKen needed a `workflow_dispatch` run to get there, and
  anything else merged between releases does too.
- Release artifacts for six platforms — the `Release` workflow, on a `v*` tag.

Both web deploys smoke-check themselves afterwards, and a 200 is not the bar.
Every puzzle bundle must be present *and* decode to the expected number of
configurations, because a truncated asset still returns 200 — and for KenKen,
where 89 of the 96 boards carry no givens, a short bundle is not a harder
puzzle but an empty grid. Pages needs this more than Vercel does: it is served
from a subpath, so a build made without the right `--base-href` serves every
byte with a 200 and still loads blank.

Keep `FLUTTER_VERSION` in step across `ci.yml`, `release.yml`, `pages.yml`,
`ios-release.yml` and `vercel.yml`; `dart format --set-exit-if-changed` is only
reproducible against one formatter version.

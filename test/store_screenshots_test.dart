// App Store screenshot renderer.
//
// Renders the real screens at exact store pixel dimensions and writes PNGs —
// no device, no simulator, no macOS. A widget test already builds the app's
// widgets; the only things it normally lacks for a *photograph* of the app are
// real fonts (the test font draws every glyph as a box) and a repaint boundary
// to rasterize. Both are cheap to add, and the result runs on a plain Linux CI
// runner in under a minute.
//
// Opt-in: does nothing unless SCREENSHOT_OUTPUT is set, so it stays out of
// `flutter test`.
//
//   SCREENSHOT_OUTPUT=appstore-shots flutter test test/store_screenshots_test.dart
//
// or `bash tool/capture_store_screenshots.sh`, which also writes the manifest
// the uploader reads.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/main.dart';
import 'package:sudoku/ready_puzzle.dart';
import 'package:sudoku/services.dart';
import 'package:sudoku/sudoku_game.dart';

/// Real fonts, or every glyph renders as the test font's filled box.
///
/// Flutter ships Roboto and the Material icon font in its own cache, which is
/// exactly what the app asks for on Android and close enough to SF on iOS for a
/// store image. Registering them under the family names the framework will look
/// up is what turns a golden-style render into a photograph of the app.
Future<void> _loadFont(String family, List<String> candidates) async {
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(await file.readAsBytes())));
    await loader.load();
    return;
  }
  throw StateError('no font file found for $family (tried $candidates)');
}

Future<void> _loadStoreFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final body = [
    '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ];
  // Register under our own family name AND over the defaults. Registering only
  // the default names is not enough: the test binding installs its own font
  // fallback and keeps winning, which is why the first run produced perfect
  // layouts full of filled boxes. The theme below asks for 'StoreScreenshot'
  // explicitly, and that request is honoured.
  for (final family in [
    'StoreScreenshot',
    // The name flutter_test resolves a null fontFamily to. Painters that build
    // their own TextPainter — the Killer cage sums — never see the theme, so
    // without this their digits render as the test font's filled boxes.
    'FlutterTest',
    'Roboto',
    'Ahem',
    '.SF UI Text',
    '.SF UI Display',
    'monospace',
  ]) {
    await _loadFont(family, body);
  }
  await _loadFont('MaterialIcons', [
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
  // The UI uses emoji (the daily-challenge calendar, the mode icons, the
  // variant chips). Neither Roboto nor DejaVu has them, so without this they
  // render as tofu boxes — which on a store page reads as a broken app.
  try {
    await _loadFont('StoreEmoji', [
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
      '/System/Library/Fonts/Apple Color Emoji.ttc',
    ]);
  } on StateError {
    debugPrint('WARNING: no emoji font found; emoji will render as boxes');
  }
}

/// Pump real frames for about a second. Never `pumpAndSettle`: the game clock
/// is a periodic timer and the particle layer animates forever, so "wait for
/// animations to stop" would wait for ever.
Future<void> _settle(WidgetTester tester, {int steps = 8}) async {
  // Only `pump`. A real `Future.delayed` here would never complete: a widget
  // test runs in a fake-async zone where wall-clock timers do not fire unless
  // you are inside `runAsync`, and awaiting one simply hangs — which it did,
  // for nine minutes, before the test harness gave up.
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
  double scale,
) async {
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary
        .toImage(pixelRatio: scale)
        .timeout(const Duration(seconds: 60));
    final data = await image
        .toByteData(format: ui.ImageByteFormat.png)
        .timeout(const Duration(seconds: 60));
    if (data == null) throw StateError('could not encode $name');
    final dir = Directory(
      Platform.environment['SCREENSHOT_OUTPUT'] ?? 'appstore-shots',
    )..createSync(recursive: true);
    await File('${dir.path}/$name.png').writeAsBytes(data.buffer.asUint8List());
    image.dispose();
  });
  debugPrint('SHOT:$name');
}

/// Wrap a screen the way the app does, so the image is of the real thing.
Widget _app(Widget home, Locale locale) => RepaintBoundary(
  key: _boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      fontFamily: 'StoreScreenshot',
      fontFamilyFallback: const ['StoreEmoji'],
      // The screens paint their own gradient, but anything the gradient does
      // not cover falls through to this — and the default is white, which
      // showed as a bare band under the home screen.
      scaffoldBackgroundColor: GameStats.current.gradient.last,
      primarySwatch: Colors.indigo,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
    home: home,
  ),
);

late GlobalKey _boundary;

/// Play a few moves so the board in the picture looks like a game in progress
/// rather than an untouched grid.
Future<void> _playSomeMoves(WidgetTester tester, int count) async {
  final state = tester.state(find.byType(GameScreen)) as dynamic;
  final game = state.game as SudokuGame?;
  if (game == null) return;
  var placed = 0;
  for (var r = 0; r < game.gridDim && placed < count; r++) {
    for (var c = 0; c < game.gridDim && placed < count; c++) {
      if (game.grid[r][c] != 0) continue;
      game.grid[r][c] = game.solution[r][c];
      placed++;
    }
  }
  await tester.pump();
}

Future<void> _captureLocale(
  WidgetTester tester,
  Locale locale,
  String tag,
  String suffix,
  double scale,
) async {
  GameStats.localeNotifier.value = locale.languageCode;

  // 1 — the home screen, which is the first thing anyone sees.
  _boundary = GlobalKey();
  await tester.pumpWidget(_app(const HomeScreen(), locale));
  await _settle(tester);
  await _save(tester, _boundary, '$tag-01-home-$suffix', scale);

  // 2 — a classic 9x9 in progress.
  _boundary = GlobalKey();
  await tester.pumpWidget(
    _app(
      const GameScreen(
        difficulty: SudokuDifficulty.medium,
        gridSize: GridSize.standard,
        gridShape: GridShape.classic,
        gameMode: GameMode.classic,
        dailySeed: 20260920,
      ),
      locale,
    ),
  );
  await _settle(tester, steps: 16);
  await _playSomeMoves(tester, 12);
  await _settle(tester, steps: 3);
  await _save(tester, _boundary, '$tag-02-classic-$suffix', scale);

  // 3 — Thermo, the newest variant.
  _boundary = GlobalKey();
  await tester.pumpWidget(
    _app(
      const GameScreen(
        difficulty: SudokuDifficulty.medium,
        gridSize: GridSize.standard,
        gridShape: GridShape.classic,
        gameMode: GameMode.classic,
        variant: SudokuVariant.thermo,
      ),
      locale,
    ),
  );
  await _settle(tester, steps: 20);
  await _save(tester, _boundary, '$tag-03-thermo-$suffix', scale);

  // 4 — Killer, cages and sums.
  _boundary = GlobalKey();
  await tester.pumpWidget(
    _app(
      const GameScreen(
        difficulty: SudokuDifficulty.medium,
        gridSize: GridSize.standard,
        gridShape: GridShape.classic,
        gameMode: GameMode.classic,
        variant: SudokuVariant.killer,
      ),
      locale,
    ),
  );
  await _settle(tester, steps: 20);
  await _save(tester, _boundary, '$tag-04-killer-$suffix', scale);

  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester, steps: 2);
}

Future<void> _captureDevice(
  WidgetTester tester, {
  required Size logicalSize,
  required double scale,
  required String suffix,
}) async {
  await tester.binding.setSurfaceSize(logicalSize);
  tester.view.physicalSize = logicalSize * scale;
  tester.view.devicePixelRatio = scale;
  // No notch or home-indicator insets: SafeArea would otherwise leave a band
  // of bare Scaffold background at the bottom of the image.
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding.zero;
  await _captureLocale(tester, const Locale('en'), 'en-US', suffix, scale);
  await _captureLocale(tester, const Locale('de'), 'de-DE', suffix, scale);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final output = Platform.environment['SCREENSHOT_OUTPUT'];
  if (output == null || output.isEmpty) {
    test('store screenshot rendering is opt-in', () {}, skip: true);
    return;
  }

  testWidgets('render the App Store scenes', (tester) async {
    await tester.runAsync(_loadStoreFonts);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    // Quiet, reproducible confetti, and a fixed board from each bundle.
    debugParticleSeed = 11;
    ThermoPuzzleBundle.debugSeed = 11;
    // flutter_test disables shadows by default, which draws every elevation as
    // a hard black rectangle — the buttons came out looking outlined in ink.
    debugDisableShadows = false;
    // kDebugMode is true under `flutter test`, so the admin panel would appear
    // on the home screen. Not in a picture of the shipped app.
    final wasDebug = GameStats.debugMode;
    GameStats.debugMode = false;
    addTearDown(() {
      debugParticleSeed = null;
      ThermoPuzzleBundle.debugSeed = null;
      GameStats.debugMode = wasDebug;
    });
    // `debugDefaultTargetPlatformOverride` and `debugDisableShadows` are
    // framework debug variables, and the test binding asserts they are back to
    // their defaults when the test body *returns* — before addTearDown runs.
    // Resetting them there fails the test even though everything worked.
    // Reset them at the end of the body instead.

    await tester.runAsync(() async {
      await PuzzleCache().initialize();
      await ReadyPuzzleCache().initialize();
      await KillerPuzzleBundle().initialize();
      await ThermoPuzzleBundle().initialize();
      await GameStats.load();
    });

    // 1320x2868 — the 6.9" iPhone, which Apple also accepts for the 6.7" slot.
    await _captureDevice(
      tester,
      logicalSize: const Size(440, 956),
      scale: 3,
      suffix: 'iphone',
    );
    // 2064x2752 — the 13" iPad Pro.
    await _captureDevice(
      tester,
      logicalSize: const Size(1032, 1376),
      scale: 2,
      suffix: 'ipad',
    );

    await tester.binding.setSurfaceSize(null);
    debugDefaultTargetPlatformOverride = null;
    debugDisableShadows = true;
  }, timeout: const Timeout(Duration(minutes: 10)));
}

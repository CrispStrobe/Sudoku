import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game_stats.dart';
import 'home_screen.dart';
import 'killer_bundle.dart';
import 'thermo_bundle.dart';
import 'l10n/app_localizations.dart';
import 'ready_puzzle.dart';
import 'services.dart';

export 'game_stats.dart';
export 'killer_bundle.dart';
export 'thermo_bundle.dart';
export 'achievements.dart';
export 'particles.dart';
export 'home_screen.dart';
export 'game_screen.dart';
export 'explain_screen.dart';
export 'admin_screen.dart';
export 'clock_format.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PuzzleCache().initialize();
  await ReadyPuzzleCache().initialize();
  await KillerPuzzleBundle().initialize();
  await ThermoPuzzleBundle().initialize();
  await GameStats.load();
  runApp(const SudokuApp());
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: GameStats.localeNotifier,
      builder: (context, localeCode, _) {
        return MaterialApp(
          title: 'CrispSudoku',
          theme: ThemeData(
            primarySwatch: Colors.indigo,
            // No explicit fontFamily: 'Roboto' is NOT bundled (it's an Android
            // system font, absent on iOS), so referencing it left text with no
            // usable font — and an emoji-only fontFamilyFallback made it worse,
            // rendering all text as tofu boxes in some build/launch paths. Let
            // each platform use its own default (SF Pro on iOS, Roboto on
            // Android); both also render emoji via the system.
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          locale: localeCode == null ? null : Locale(localeCode),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // Resolve the platform's locale ourselves rather than trusting the
          // default algorithm with it.
          //
          // A browser can report `C` — the bare POSIX locale, which is what a
          // container or a Linux box with no LANG set hands over — and `C` is
          // not a language tag. It reached `Intl.canonicalizedLocale`, which
          // threw `Incorrect locale information provided` during startup, and
          // a Flutter web app that throws while starting renders nothing at
          // all: a blank blue rectangle, with every asset served correctly and
          // a 200 on every request. Found by the deploy render check on a CI
          // runner, which is exactly the kind of machine that reports `C`.
          //
          // Match by language code, then fall back to the first supported
          // locale. Never let an unrecognised tag through.
          localeResolutionCallback: (locale, supported) {
            if (locale != null) {
              for (final candidate in supported) {
                if (candidate.languageCode == locale.languageCode) {
                  return candidate;
                }
              }
            }
            return supported.first;
          },
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

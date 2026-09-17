import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game_stats.dart';
import 'home_screen.dart';
import 'l10n/app_localizations.dart';
import 'ready_puzzle.dart';
import 'services.dart';

export 'game_stats.dart';
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
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

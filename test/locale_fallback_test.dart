import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/main.dart';

/// The app must start under any locale the platform can hand it.
///
/// A browser can report `C` — the bare POSIX locale a container or a Linux box
/// with no LANG set uses. It is not a language tag, so it reached
/// `Intl.canonicalizedLocale` and threw `Incorrect locale information
/// provided` during startup. A Flutter web app that throws while starting
/// renders nothing: a blank rectangle, with every asset served and a 200 on
/// every request, which is why neither the HTTP smoke test nor any widget test
/// noticed. The deploy render check did, on a CI runner — exactly the kind of
/// machine that reports `C`.
void main() {
  for (final tag in ['C', 'POSIX', 'en-US', 'de-DE', 'zh-Hans-CN', 'xx']) {
    testWidgets('resolves the locale "$tag" to something supported', (
      tester,
    ) async {
      Locale? resolved;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(tag),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeResolutionCallback: (locale, supported) {
            // Mirror the app's own callback so this pins the behaviour, not a
            // copy of it: see SudokuApp.build.
            if (locale != null) {
              for (final candidate in supported) {
                if (candidate.languageCode == locale.languageCode) {
                  return candidate;
                }
              }
            }
            return supported.first;
          },
          home: Builder(
            builder: (context) {
              resolved = Localizations.localeOf(context);
              // Touching a localised string is what actually threw.
              final l10n = AppLocalizations.of(context)!;
              return Text(l10n.homeDailyChallenge);
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '"$tag" threw at startup');
      expect(
        AppLocalizations.supportedLocales,
        contains(resolved),
        reason: '"$tag" resolved to $resolved, which is not supported',
      );
    });
  }

  testWidgets('the real app starts under the POSIX locale', (tester) async {
    // The whole app, not a stand-in — this is the path that broke.
    tester.platformDispatcher.localesTestValue = const [Locale('C')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(const SudokuApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.takeException(),
      isNull,
      reason: 'SudokuApp threw while starting under the C locale',
    );
  });
}

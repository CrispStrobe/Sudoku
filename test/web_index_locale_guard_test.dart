import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `web/index.html` carries a locale guard, and nothing else can check it.
///
/// A browser may report the bare POSIX locale `C`, which is not a language tag:
/// `new Intl.DateTimeFormat('C')` throws `RangeError: Invalid language tag`.
/// The Flutter engine reads `navigator.language` during startup, so the app
/// died before painting a frame — a blank white page, every asset served, 200
/// on every request. The Dart-side `localeResolutionCallback` cannot help: by
/// the time any Dart runs, the engine has already read the value.
///
/// So the fix lives in the HTML shell, where no Dart test can exercise it. This
/// at least pins that it is still there and still runs before the bootstrap —
/// the failure it prevents is invisible in every other check, and an
/// `index.html` is exactly the file someone regenerates from the Flutter
/// template without noticing what was in it.
void main() {
  test('index.html guards the browser locale before flutter_bootstrap', () {
    final html = File('web/index.html').readAsStringSync();

    expect(
      html,
      contains('Intl.getCanonicalLocales'),
      reason:
          'the locale guard is gone from web/index.html — a browser reporting '
          'the POSIX locale "C" will render a blank page',
    );
    expect(html, contains("Object.defineProperty(navigator, 'language'"));
    expect(html, contains("Object.defineProperty(navigator, 'languages'"));

    // Order matters: the engine reads navigator.language as it boots. Match
    // the script *tag*, not the string — the guard's own comment names the
    // file too, and the first occurrence of that is the comment.
    final guard = html.indexOf('Intl.getCanonicalLocales');
    final bootstrap = html.indexOf('<script src="flutter_bootstrap.js"');
    expect(guard, greaterThanOrEqualTo(0));
    expect(bootstrap, greaterThanOrEqualTo(0));
    expect(
      guard,
      lessThan(bootstrap),
      reason:
          'the locale guard must run before flutter_bootstrap.js, or the '
          'engine has already read the bad locale',
    );
  });
}

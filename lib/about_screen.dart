// About / legal info for CrispSudoku. Layout mirrors the sibling apps
// (CrispCalc, CrisperWeaver) so the family is visually consistent: an app
// header card, then sections for service provider, contact, privacy,
// disclaimer and license. The bottom button opens Flutter's `showLicensePage`,
// which lists every bundled open-source dependency's license.

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appName = 'CrispSudoku';
  static const _email = 'postmaster@crispstro.be';
  static const _provider =
      'Christian Ströbele\nNikolausstr. 5\n70190 Stuttgart\nDeutschland / Germany';
  static const _tagline =
      'Classic, jigsaw, Sudoku-X & Killer puzzles with a daily challenge.';

  static const _privacyText =
      'CrispSudoku runs entirely on-device. Your games, statistics and '
      'settings never leave your device — there is no account, no analytics '
      'and no contact with remote services.';
  static const _disclaimerText =
      'CrispSudoku is provided "as is", without warranty of any kind. Every '
      'generated puzzle is verified to have a unique solution, but use the '
      'app at your own discretion.';
  static const _licenseText =
      'CrispSudoku is free software, distributed under the GNU Affero General '
      'Public License version 3 or later. As the sole copyright holder, the '
      'author additionally makes official binary distributions (e.g. via the '
      'Apple App Store and Google Play) available under those stores’ '
      'standard terms; this does not affect your rights to the source under '
      'AGPL-3.0.';

  /// Build-time override via `--dart-define=APP_VERSION=v1.0.0`, set by CI
  /// release builds so the screen matches the release tag. Empty in local
  /// builds, which fall back to `package_info_plus` (reads pubspec).
  static const _buildVersion = String.fromEnvironment('APP_VERSION');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _AppHeader(),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.business,
            label: 'Service provider',
            child: const Text(_provider),
          ),
          _SectionCard(
            icon: Icons.alternate_email,
            label: 'Contact',
            child: InkWell(
              onTap: () => _open('mailto:$_email'),
              child: const Text(
                _email,
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          _SectionCard(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy',
            child: const Text(_privacyText),
          ),
          _SectionCard(
            icon: Icons.gavel,
            label: 'Disclaimer',
            child: const Text(_disclaimerText),
          ),
          _SectionCard(
            icon: Icons.copyright,
            label: 'License',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(_licenseText),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () =>
                      _open('https://www.gnu.org/licenses/agpl-3.0.html'),
                  child: const Text(
                    'https://www.gnu.org/licenses/agpl-3.0.html',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open-source licenses'),
            onPressed: () async {
              final info = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              final version = _buildVersion.isNotEmpty
                  ? _buildVersion
                  : '${info.version}+${info.buildNumber}';
              showLicensePage(
                context: context,
                applicationName: _appName,
                applicationVersion: version,
                applicationLegalese:
                    '© ${DateTime.now().year} Christian Ströbele — AGPL-3.0',
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final v = AboutScreen._buildVersion.isNotEmpty
            ? AboutScreen._buildVersion
            : snap.hasData
            ? '${snap.data!.version} (${snap.data!.buildNumber})'
            : '…';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.grid_on,
                    size: 28,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AboutScreen._appName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version $v',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AboutScreen._tagline,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

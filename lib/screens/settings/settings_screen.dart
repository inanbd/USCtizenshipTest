import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/progress_sync.dart';
import '../../providers/settings_provider.dart';
import '../../services/tts_service.dart';
import '../auth/sign_in_screen.dart';
import 'officials_screen.dart';
import 'state_info_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            _header(context, 'Account'),
            const _AccountTile(),

            _header(context, 'Test'),
            ListTile(
              leading: const Icon(Icons.rule_rounded),
              title: const Text('Test version'),
              subtitle: Text(settings.testVersion.label),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<TestVersion>(
                segments: const [
                  ButtonSegment(
                    value: TestVersion.v2008,
                    label: Text('2008 · 100Q'),
                  ),
                  ButtonSegment(
                    value: TestVersion.v2020,
                    label: Text('2020 · 128Q'),
                  ),
                ],
                selected: {settings.testVersion},
                onSelectionChanged: (s) =>
                    context.read<SettingsProvider>().setTestVersion(s.first),
              ),
            ),
            const SizedBox(height: 8),

            _header(context, 'Appearance'),
            RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (m) {
                if (m != null) {
                  context.read<SettingsProvider>().setThemeMode(m);
                }
              },
              child: const Column(
                children: [
                  RadioListTile(
                    value: ThemeMode.system,
                    title: Text('Match system'),
                  ),
                  RadioListTile(value: ThemeMode.light, title: Text('Light')),
                  RadioListTile(value: ThemeMode.dark, title: Text('Dark')),
                ],
              ),
            ),

            _header(context, 'Audio'),
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: const Text('Speech speed'),
              subtitle: Slider(
                value: settings.ttsRate,
                min: 0.25,
                max: 0.75,
                divisions: 10,
                label: '${(settings.ttsRate / 0.5).toStringAsFixed(2)}x',
                onChanged: (v) {
                  context.read<SettingsProvider>().setTtsRate(v);
                  context.read<TtsService>().setRate(v);
                },
              ),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_outline_rounded),
                tooltip: 'Preview',
                onPressed: () => context.read<TtsService>().speak(
                  'What is the supreme law of the land?',
                ),
              ),
            ),

            _header(context, 'Answers that change'),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('My state info'),
              subtitle: Text(
                settings.stateInfo == null
                    ? 'Not set — needed for state-specific questions'
                    : '${settings.stateInfo!.name} · capital ${settings.stateInfo!.capital}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StateInfoScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_rounded),
              title: const Text('Current officials'),
              subtitle: Text('President: ${settings.officials.president}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OfficialsScreen()),
              ),
            ),

            _header(context, 'Progress'),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Reset "known" marks'),
              subtitle: Text('For the ${settings.testVersion.shortLabel} set'),
              onTap: () => _confirmReset(context, settings.testVersion),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded),
              title: const Text('Clear mock test history'),
              onTap: () async {
                await context.read<ProgressProvider>().clearHistory();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('History cleared.')),
                  );
                }
              },
            ),

            _header(context, 'About'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(
                'Questions are the official USCIS civics questions (2008 and '
                '2020 versions). Some answers depend on where you live or on '
                'who currently holds office — always verify current officials '
                'at uscis.gov/citizenship/testupdates. This app is a study aid '
                'and is not affiliated with USCIS.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    ),
  );

  Future<void> _confirmReset(BuildContext context, TestVersion version) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset progress?'),
        content: Text(
          'This clears your "known" marks for the ${version.shortLabel} set.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ProgressProvider>().resetLearned(version);
    }
  }
}

/// Shows who is signed in, or offers to sign in so progress syncs.
class _AccountTile extends StatelessWidget {
  const _AccountTile();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isSignedIn) {
      return ListTile(
        leading: const Icon(Icons.cloud_off_rounded),
        title: const Text('Not signed in'),
        subtitle: const Text('Sign in to sync progress with the website'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SignInScreen())),
      );
    }

    return ListTile(
      leading: const Icon(Icons.cloud_done_rounded),
      title: Text(auth.user?.label ?? 'Signed in'),
      subtitle: const Text('Progress syncs with the website'),
      trailing: TextButton(
        onPressed: () async {
          final version = context.read<SettingsProvider>().testVersion;
          // Push anything studied on this device before the session ends.
          await context.read<ProgressSync>().pushAll(version);
          if (!context.mounted) return;
          await context.read<AuthProvider>().logout();
        },
        child: const Text('Sign out'),
      ),
    );
  }
}

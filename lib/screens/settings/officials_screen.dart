import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/officials.dart';
import '../../providers/settings_provider.dart';

/// Edits the answers to the time-sensitive federal questions, plus the
/// Congress.gov API key used to refresh state reps.
class OfficialsScreen extends StatefulWidget {
  const OfficialsScreen({super.key});

  @override
  State<OfficialsScreen> createState() => _OfficialsScreenState();
}

class _OfficialsScreenState extends State<OfficialsScreen> {
  late final TextEditingController _president;
  late final TextEditingController _vp;
  late final TextEditingController _speaker;
  late final TextEditingController _chief;
  late final TextEditingController _party;
  late final TextEditingController _apiKey;

  @override
  void initState() {
    super.initState();
    final o = context.read<SettingsProvider>().officials;
    _president = TextEditingController(text: o.president);
    _vp = TextEditingController(text: o.vicePresident);
    _speaker = TextEditingController(text: o.speaker);
    _chief = TextEditingController(text: o.chiefJustice);
    _party = TextEditingController(text: o.presidentParty);
    _apiKey = TextEditingController(
      text: context.read<SettingsProvider>().congressApiKey,
    );
  }

  @override
  void dispose() {
    _president.dispose();
    _vp.dispose();
    _speaker.dispose();
    _chief.dispose();
    _party.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>();
    await settings.setOfficials(
      Officials(
        president: _president.text.trim(),
        vicePresident: _vp.text.trim(),
        speaker: _speaker.text.trim(),
        chiefJustice: _chief.text.trim(),
        presidentParty: _party.text.trim(),
        asOf: DateTime.now(),
      ),
    );
    await settings.setCongressApiKey(_apiKey.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved.')));
      Navigator.of(context).pop();
    }
  }

  void _resetDefaults() {
    final d = Officials.defaults;
    setState(() {
      _president.text = d.president;
      _vp.text = d.vicePresident;
      _speaker.text = d.speaker;
      _chief.text = d.chiefJustice;
      _party.text = d.presidentParty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asOf = context.read<SettingsProvider>().officials.asOf;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Current officials'),
        actions: [
          TextButton(onPressed: _resetDefaults, child: const Text('Defaults')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.update_rounded,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'These answers change with elections and appointments. '
                        'Verify the current ones at '
                        'uscis.gov/citizenship/testupdates.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (asOf != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Last set ${DateFormat.yMMMd().format(asOf)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            _field('President', _president, Icons.person_rounded),
            _field('Vice President', _vp, Icons.person_outline_rounded),
            _field('Speaker of the House', _speaker, Icons.gavel_rounded),
            _field('Chief Justice', _chief, Icons.balance_rounded),
            _field("President's political party", _party, Icons.flag_rounded),
            const SizedBox(height: 24),
            Text(
              'Congress.gov API key (optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Used to refresh your state\'s senators and representatives. '
              'Get a free key at api.congress.gov/sign-up.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKey,
              decoration: const InputDecoration(
                labelText: 'API key',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
      );
}

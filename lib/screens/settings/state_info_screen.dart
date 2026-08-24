import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/state_data.dart';
import '../../models/state_info.dart';
import '../../providers/settings_provider.dart';
import '../../services/congress_api_service.dart';

/// Lets the user pick their state (bundled capital) and enter/refresh the
/// person-name answers (governor, senators, representative).
class StateInfoScreen extends StatefulWidget {
  const StateInfoScreen({super.key});

  @override
  State<StateInfoScreen> createState() => _StateInfoScreenState();
}

class _StateInfoScreenState extends State<StateInfoScreen> {
  StateInfo? _selected;
  final _governor = TextEditingController();
  final _senator1 = TextEditingController();
  final _senator2 = TextEditingController();
  final _representative = TextEditingController();
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<SettingsProvider>().stateInfo;
    if (existing != null) _applyState(existing);
  }

  void _applyState(StateInfo info) {
    _selected = info;
    _governor.text = info.governor ?? '';
    _senator1.text = info.senators.isNotEmpty ? info.senators[0] : '';
    _senator2.text = info.senators.length > 1 ? info.senators[1] : '';
    _representative.text = info.representative ?? '';
  }

  @override
  void dispose() {
    _governor.dispose();
    _senator1.dispose();
    _senator2.dispose();
    _representative.dispose();
    super.dispose();
  }

  void _onPickState(String? code) {
    if (code == null) return;
    final base = stateByCode(code);
    if (base == null) return;
    final existing = context.read<SettingsProvider>().stateInfo;
    setState(() {
      if (existing != null && existing.code == code) {
        _applyState(existing);
      } else {
        _applyState(base);
      }
    });
  }

  Future<void> _save() async {
    final base = _selected;
    if (base == null) return;
    final senators = [
      _senator1.text.trim(),
      _senator2.text.trim(),
    ].where((s) => s.isNotEmpty).toList();
    final info = base.copyWith(
      governor: _governor.text.trim(),
      senators: senators,
      representative: _representative.text.trim(),
      updatedAt: DateTime.now(),
      source: StateDataSource.manual,
    );
    await context.read<SettingsProvider>().setStateInfo(info);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('State info saved.')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _refreshFromApi() async {
    final base = _selected;
    if (base == null) return;
    final settings = context.read<SettingsProvider>();
    final key = settings.congressApiKey;
    if (key.trim().isEmpty) {
      _showApiKeyHelp();
      return;
    }
    setState(() => _refreshing = true);
    final api = context.read<CongressApiService>();
    try {
      final senators = await api.fetchSenators(base.code, key);
      if (senators.isNotEmpty) {
        _senator1.text = senators.isNotEmpty ? senators[0] : '';
        _senator2.text = senators.length > 1 ? senators[1] : '';
      }
      final reps = await api.fetchRepresentatives(base.code, key);
      if (mounted && reps.isNotEmpty) {
        await _pickRepresentative(reps);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refreshed from Congress.gov.')),
        );
      }
    } on CongressApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _pickRepresentative(List<CongressMember> reps) async {
    final chosen = await showDialog<CongressMember>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pick your U.S. Representative'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              'Choose the representative for your congressional district.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ...reps.map(
            (r) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Text(
                r.district != null && r.district!.isNotEmpty
                    ? '${r.name} — District ${r.district}'
                    : r.name,
              ),
            ),
          ),
        ],
      ),
    );
    if (chosen != null) _representative.text = chosen.name;
  }

  void _showApiKeyHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Congress.gov API key needed'),
        content: const Text(
          'Live refresh uses the free Congress.gov API. Get a key at '
          'api.congress.gov/sign-up, then add it in Settings › Current '
          'officials. You can always enter names by hand instead.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDc = _selected?.isDistrictOfColumbia ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('My State Info')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Pick your state. The capital is built in; enter or refresh the '
              'people who represent you.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selected?.code,
              decoration: const InputDecoration(labelText: 'State'),
              isExpanded: true,
              items: [
                for (final s in kStates)
                  DropdownMenuItem(value: s.code, child: Text(s.name)),
              ],
              onChanged: _onPickState,
            ),
            if (_selected != null) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_city_rounded),
                  title: const Text('State capital'),
                  subtitle: Text(
                    isDc
                        ? 'D.C. is not a state and has no capital.'
                        : _selected!.capital,
                  ),
                ),
              ),
              if (!isDc) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _refreshing ? null : _refreshFromApi,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_rounded),
                  label: Text(
                    _refreshing
                        ? 'Refreshing…'
                        : 'Refresh reps from Congress.gov',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _governor,
                  decoration: const InputDecoration(
                    labelText: 'Governor',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senator1,
                  decoration: const InputDecoration(
                    labelText: 'U.S. Senator 1',
                    prefixIcon: Icon(Icons.account_balance_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senator2,
                  decoration: const InputDecoration(
                    labelText: 'U.S. Senator 2',
                    prefixIcon: Icon(Icons.account_balance_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _representative,
                  decoration: const InputDecoration(
                    labelText: 'U.S. Representative',
                    prefixIcon: Icon(Icons.how_to_vote_rounded),
                    helperText: 'Depends on your congressional district',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

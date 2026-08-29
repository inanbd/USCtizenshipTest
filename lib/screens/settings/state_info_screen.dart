import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../data/state_data.dart';
import '../../models/state_answers.dart';
import '../../models/state_info.dart';
import '../../providers/settings_provider.dart';
import '../../services/state_answers_service.dart';

/// Lets the user pick their state and fill in the person-name answers.
///
/// The capital is bundled, so it works offline. Governor, senators and the list
/// of House members are fetched from the backend (which owns the Congress.gov
/// key) and cached on the device. Every field stays editable, and anything the
/// user types is remembered as manual so a later refresh leaves it alone.
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

  StateAnswers? _answers;
  bool _refreshing = false;
  String? _status;

  /// Fields the user has taken ownership of by typing in them (or, for the
  /// representative, by choosing one). A fetch never overwrites these.
  Set<String> _manual = {};

  @override
  void initState() {
    super.initState();
    final existing = context.read<SettingsProvider>().stateInfo;
    if (existing != null) {
      _applyState(existing);
      _manual = {...existing.manualFields};
      _answers = context.read<StateAnswersService>().cached(existing.code);
    }
  }

  /// Typing in a field claims it; emptying it hands control back to the fetch.
  void _onEdited(String field, String value) {
    final owned = value.trim().isNotEmpty;
    if (_manual.contains(field) == owned) return;
    setState(() => owned ? _manual.add(field) : _manual.remove(field));
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
    final cached = context.read<StateAnswersService>().cached(code);
    setState(() {
      _status = null;
      _answers = cached;
      if (existing != null && existing.code == code) {
        _applyState(existing);
        _manual = {...existing.manualFields};
      } else {
        _manual = {};
        _applyState(base);
        // A cached payload for a state the user has not saved yet still fills
        // the form, so switching back to a state you looked at before is free.
        if (cached != null) _applyState(base.applyFetched(cached));
      }
    });
  }

  /// The state as the form currently reads it.
  StateInfo _formState() => _selected!.copyWith(
    governor: _governor.text.trim(),
    senators: [
      _senator1.text.trim(),
      _senator2.text.trim(),
    ].where((s) => s.isNotEmpty).toList(),
    representative: _representative.text.trim(),
    updatedAt: DateTime.now(),
    source: _manual.isEmpty && _answers != null
        ? StateDataSource.api
        : StateDataSource.manual,
    manualFields: _manual,
  );

  Future<void> _save() async {
    if (_selected == null) return;
    await context.read<SettingsProvider>().setStateInfo(_formState());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('State info saved.')));
    Navigator.of(context).pop();
  }

  Future<void> _refresh() async {
    final base = _selected;
    if (base == null) return;

    setState(() {
      _refreshing = true;
      _status = null;
    });

    final service = context.read<StateAnswersService>();
    final congressKey = context.read<SettingsProvider>().congressApiKey;
    StateAnswers? answers;
    String? status;
    try {
      answers = await service.fetch(base.code, congressApiKey: congressKey);
    } on ApiException catch (e) {
      answers = service.cached(base.code);
      status = answers == null
          ? e.message
          : '${e.message} Showing the copy saved on this device.';
    }

    if (!mounted) return;

    // The spinner stops before the picker opens, so the dialog is the only
    // thing waiting on the user.
    if (answers == null) {
      setState(() {
        _refreshing = false;
        _status = status;
      });
      return;
    }

    // Manual entries win: applyFetched skips any field the user owns.
    final merged = _formState().applyFetched(answers);
    setState(() {
      _refreshing = false;
      _answers = answers;
      _applyState(merged);
      _status = status ?? answers!.congressNotice;
    });

    // Only prompt when there is nothing to keep - re-asking on every refresh
    // would be nagging, and the button below reopens the list on demand.
    if (answers.representatives.isNotEmpty &&
        _representative.text.trim().isEmpty) {
      await _pickRepresentative(answers.representatives);
    }
  }

  Future<void> _pickRepresentative(List<CongressMemberAnswer> reps) async {
    final chosen = await showDialog<CongressMemberAnswer>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pick your U.S. Representative'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              'Choose the representative for your congressional district. '
              'Not sure which district you are in? Look up your address at '
              'house.gov.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final r in reps)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Text(r.label),
            ),
        ],
      ),
    );
    if (chosen != null && mounted) {
      setState(() {
        _representative.text = chosen.name;
        _manual.add(StateInfo.fieldRepresentative);
      });
    }
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
              'Pick your state. The capital is built in; the people who '
              'represent you come from the Civics Prep server, and anything you '
              'type yourself is kept.',
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
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_rounded),
                  label: Text(
                    _refreshing ? 'Fetching…' : 'Fetch my state answers',
                  ),
                ),
                if (_answers != null) _FreshnessLine(answers: _answers!),
                if (_status != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _status!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _governor,
                  onChanged: (v) => _onEdited(StateInfo.fieldGovernor, v),
                  decoration: const InputDecoration(
                    labelText: 'Governor',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                    helperText: 'Edit to override the fetched name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senator1,
                  onChanged: (_) => _onEdited(
                    StateInfo.fieldSenators,
                    _senator1.text + _senator2.text,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'U.S. Senator 1',
                    prefixIcon: Icon(Icons.account_balance_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senator2,
                  onChanged: (_) => _onEdited(
                    StateInfo.fieldSenators,
                    _senator1.text + _senator2.text,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'U.S. Senator 2',
                    prefixIcon: Icon(Icons.account_balance_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _representative,
                  onChanged: (v) => _onEdited(StateInfo.fieldRepresentative, v),
                  decoration: const InputDecoration(
                    labelText: 'U.S. Representative',
                    prefixIcon: Icon(Icons.how_to_vote_rounded),
                    helperText: 'Depends on your congressional district',
                  ),
                ),
                if ((_answers?.representatives.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        _pickRepresentative(_answers!.representatives),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: Text(
                      'Pick from ${_answers!.representatives.length} '
                      '${_selected!.name} representatives',
                    ),
                  ),
                ],
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

/// Says how old the fetched answers are — the thing a user needs to judge
/// whether to trust them the week of their interview.
class _FreshnessLine extends StatelessWidget {
  const _FreshnessLine({required this.answers});

  final StateAnswers answers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>['Fetched ${_ago(answers.fetchedAt)}'];
    final asOf = answers.governor?.asOf;
    if (asOf != null) {
      parts.add(
        'governor verified ${asOf.year}-'
        '${asOf.month.toString().padLeft(2, '0')}-'
        '${asOf.day.toString().padLeft(2, '0')}',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        parts.join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static String _ago(DateTime when) {
    final days = DateTime.now().difference(when).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }
}

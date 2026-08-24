import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../models/enums.dart';
import '../../models/question.dart';
import '../../models/study_plan.dart';
import '../../providers/settings_provider.dart';
import '../../providers/study_plan_provider.dart';
import '../browse/question_detail_screen.dart';

class StudyPlanScreen extends StatelessWidget {
  const StudyPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final planProvider = context.watch<StudyPlanProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Plan'),
        actions: [
          if (planProvider.hasPlan)
            IconButton(
              tooltip: 'Clear plan',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear study plan?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  context.read<StudyPlanProvider>().clearPlan();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: planProvider.hasPlan
            ? _PlanView(plan: planProvider.plan!)
            : const _CreatePlanView(),
      ),
    );
  }
}

class _CreatePlanView extends StatefulWidget {
  const _CreatePlanView();

  @override
  State<_CreatePlanView> createState() => _CreatePlanViewState();
}

class _CreatePlanViewState extends State<_CreatePlanView> {
  DateTime _testDate = DateTime.now().add(const Duration(days: 14));
  bool _seniorOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final version = settings.testVersion;
    final days = _testDate.difference(_dateOnly(DateTime.now())).inDays + 1;
    final total = _seniorOnly
        ? QuestionRepository.senior(version).length
        : QuestionRepository.forVersion(version).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pick your interview date and we\'ll spread all $total '
                    'questions across the days, with review days built in.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Test date',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month_rounded),
            title: Text(DateFormat.yMMMMEEEEd().format(_testDate)),
            subtitle: Text(
              days <= 1 ? 'Cram mode (today)' : '$days days to study',
            ),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: _pickDate,
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('65/20 questions only'),
          subtitle: const Text(
            'For applicants 65+ who have been residents 20+ years',
          ),
          value: _seniorOnly,
          onChanged: (v) => setState(() => _seniorOnly = v),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            context.read<StudyPlanProvider>().createPlan(
              version: version,
              testDate: _testDate,
              seniorOnly: _seniorOnly,
            );
          },
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Create study plan'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _testDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _testDate = picked);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan});
  final StudyPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = _dateOnly(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${plan.version.shortLabel} plan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Test: ${DateFormat.yMMMd().format(plan.testDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: plan.progress,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${plan.completedCount} of ${plan.totalDays} days complete',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...plan.days.map(
          (day) => _DayTile(
            plan: plan,
            day: day,
            isToday: _dateOnly(day.date) == today,
          ),
        ),
      ],
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.plan,
    required this.day,
    required this.isToday,
  });

  final StudyPlan plan;
  final StudyDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = plan.completedDayNumbers.contains(day.dayNumber);
    final questions = day.questionIds
        .map((id) => QuestionRepository.byId(plan.version, id))
        .whereType<Question>()
        .toList();

    return Card(
      color: isToday ? theme.colorScheme.primaryContainer : null,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Checkbox(
          value: done,
          onChanged: (_) => context.read<StudyPlanProvider>().toggleDayComplete(
            day.dayNumber,
          ),
        ),
        title: Row(
          children: [
            Text(
              'Day ${day.dayNumber}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TODAY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${DateFormat.MMMEd().format(day.date)} · '
          '${day.isReviewDay ? "Review ${questions.length} questions" : "${questions.length} new questions"}',
        ),
        children: questions
            .map(
              (q) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Text('${q.id}', style: const TextStyle(fontSize: 11)),
                ),
                title: Text(
                  q.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuestionDetailScreen(question: q),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

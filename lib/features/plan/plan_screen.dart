import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../widgets/settings_button.dart';
import '../scheduling/help_me_plan_screen.dart';
import 'calendar_pane.dart';
import 'unscheduled_list_pane.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  static const double _wideBreakpoint = 600;

  void _selectDate(BuildContext context, WidgetRef ref) async {
    final selectedDate = ref.read(selectedPlanDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      ref.read(selectedPlanDateProvider.notifier).setDate(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedPlanDateProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final allowOverlap = ref.watch(allowOverlapProvider);
    final dateFormatted = DateFormat('EEE, MMM d').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _selectDate(context, ref),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Text(
                    'Plan — $dateFormatted',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
        actions: [
          Tooltip(
            message: 'Allow overlapping tasks',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Switch(
                value: allowOverlap,
                onChanged: (value) => ref.read(allowOverlapProvider.notifier).set(value),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Help me plan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpMePlanScreen()),
            ),
          ),
          const SettingsButton(),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 2, child: DayCalendarView(today: selectedDate)),
                const VerticalDivider(width: 1),
                Expanded(flex: 1, child: UnscheduledTaskList(today: selectedDate)),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 2, child: DayCalendarView(today: selectedDate)),
                const Divider(height: 1),
                Expanded(child: UnscheduledTaskList(today: selectedDate)),
              ],
            ),
    );
  }
}

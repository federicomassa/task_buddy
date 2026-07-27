import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../widgets/settings_button.dart';
import '../scheduling/help_me_plan_screen.dart';
import 'calendar_pane.dart';
import 'unscheduled_list_pane.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  static const double _wideBreakpoint = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedPlanDateProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final allowOverlap = ref.watch(allowOverlapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
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

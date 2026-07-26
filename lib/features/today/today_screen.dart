import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../widgets/settings_button.dart';
import '../../widgets/sign_out_button.dart';
import '../plan/help_me_plan_screen.dart';
import 'calendar_pane.dart';
import 'unscheduled_list_pane.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  static const double _wideBreakpoint = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Help me plan',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HelpMePlanScreen()),
            ),
          ),
          const SettingsButton(),
          const SignOutButton(),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 2, child: DayCalendarView(today: today)),
                const VerticalDivider(width: 1),
                Expanded(flex: 1, child: UnscheduledTaskList(today: today)),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 2, child: DayCalendarView(today: today)),
                const Divider(height: 1),
                Expanded(child: UnscheduledTaskList(today: today)),
              ],
            ),
    );
  }
}

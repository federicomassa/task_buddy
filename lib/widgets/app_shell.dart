import 'package:flutter/material.dart';

import '../features/categories/categories_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/tasks/tasks_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
    NavigationDestination(icon: Icon(Icons.check_box_outlined), selectedIcon: Icon(Icons.check_box), label: 'Tasks'),
    NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Goals'),
    NavigationDestination(icon: Icon(Icons.label_outline), selectedIcon: Icon(Icons.label), label: 'Categories'),
    NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Insights'),
  ];

  static const _pages = [
    DashboardScreen(),
    TasksScreen(),
    GoalsScreen(),
    CategoriesScreen(),
    InsightsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: _destinations
                  .map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label)))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pages[_index]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _destinations,
      ),
    );
  }
}

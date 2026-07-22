import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_buddy/core/theme.dart';

void main() {
  testWidgets('app theme builds without error', (tester) async {
    final theme = buildAppTheme(Brightness.light);
    expect(theme.useMaterial3, isTrue);
  });
}

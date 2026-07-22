import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: TaskBuddyApp()));
}

class TaskBuddyApp extends StatelessWidget {
  const TaskBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Buddy',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: const AuthGate(),
    );
  }
}

/// Ensures the user is signed in (anonymously) and that habit cycles are
/// reconciled for the current period before showing the app shell.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  late final Future<void> _bootstrap = _bootstrapApp();

  Future<void> _bootstrapApp() async {
    final user = await ref.read(authServiceProvider).ensureSignedIn();
    await ref.read(habitCycleServiceProvider).reconcile(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Failed to start: ${snapshot.error}')),
          );
        }
        return const AppShell();
      },
    );
  }
}

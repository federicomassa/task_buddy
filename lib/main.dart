import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/verify_email_screen.dart';
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

/// Shows the login screen until a user is authenticated, then reconciles
/// habit cycles for the current period before showing the app shell.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('Failed to start: $error'))),
      data: (user) {
        if (user == null) return const LoginScreen();
        if (!user.emailVerified) return VerifyEmailScreen(email: user.email ?? '');
        return _Bootstrap(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _Bootstrap extends ConsumerStatefulWidget {
  final String uid;

  const _Bootstrap({super.key, required this.uid});

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  late final Future<void> _reconcile = ref.read(habitCycleServiceProvider).reconcile(widget.uid);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _reconcile,
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

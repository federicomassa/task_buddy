import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/error_reporter.dart';
import 'core/platform_support.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/verify_email_screen.dart';
import 'firebase_options.dart';
import 'providers/app_providers.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Widget build/layout/paint errors: report instead of letting the
    // framework's default handler crash the app.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // Layout overflow ("A RenderFlex overflowed...") is a debug-only
      // rendering assertion, not a real failure — it's stripped out of
      // release builds entirely. Surfacing it as a snackbar just interrupts
      // the user with a dev diagnostic; leave it to the usual debug-mode
      // overlay instead.
      if (details.exception.toString().contains('overflowed by')) return;
      reportError(details.exception);
    };

    runApp(const ProviderScope(child: TaskBuddyApp()));
  }, (error, stack) => reportError(error));
}

class TaskBuddyApp extends StatelessWidget {
  const TaskBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Buddy',
      scaffoldMessengerKey: scaffoldMessengerKey,
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
  @override
  void initState() {
    super.initState();
    // Runs in the background and streams its results into the Goals/Today
    // screens as they land, rather than gating first paint on it.
    ref
        .read(habitCycleServiceProvider)
        .reconcile(widget.uid)
        .catchError((e) => ref.read(errorReporterProvider).report(e));

    if (isAndroidPlatform) {
      _restoreDailyReminder();
    }
  }

  // Re-establishes the reminder alarm on every app open. This is what makes
  // the inexact, non-boot-persistent alarm scheduling in NotificationService
  // self-heal: even if the OS drops it across a reboot, opening the app
  // before the reminder time re-arms it.
  Future<void> _restoreDailyReminder() async {
    try {
      final notifications = ref.read(notificationServiceProvider);
      await notifications.initialize();
      final settings =
          await ref.read(userSettingsRepositoryProvider).streamSettings(widget.uid).first;
      if (settings.reminderEnabled) {
        await notifications.scheduleDailyReminder(settings.reminderMinutes);
      }
    } catch (e) {
      ref.read(errorReporterProvider).report(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AppShell();
  }
}

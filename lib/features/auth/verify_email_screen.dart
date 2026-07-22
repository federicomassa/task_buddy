import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;

  Future<void> _checkVerified() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });

    final authService = ref.read(authServiceProvider);
    await authService.reloadCurrentUser();

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (authService.currentUser?.emailVerified != true) {
      setState(() => _message = "Still not verified. Check your inbox and tap the link, then try again.");
      return;
    }

    // Refresh the auth state stream so AuthGate re-evaluates emailVerified.
    ref.invalidate(authStateProvider);
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      if (mounted) setState(() => _message = 'Verification email sent to ${widget.email}.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.mark_email_unread_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Verify your email',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We sent a verification link to ${widget.email}. Please verify your email before continuing.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isChecking ? null : _checkVerified,
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("I've verified my email"),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isResending ? null : _resend,
                    child: Text(_isResending ? 'Sending...' : 'Resend verification email'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.read(authServiceProvider).signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Shared skeleton for the auth screens (login, verify-email): a centered,
/// width-constrained column on top of a scrollable, safe-area-padded body.
class AuthScaffold extends StatelessWidget {
  final Widget child;

  const AuthScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

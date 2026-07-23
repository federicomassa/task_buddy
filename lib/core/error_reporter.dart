import 'package:flutter/material.dart';

/// Attached to [MaterialApp.scaffoldMessengerKey] so [reportError] can show
/// a snackbar from anywhere (e.g. a Zone error handler) without needing a
/// [BuildContext].
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void reportError(Object error) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
}

abstract class ErrorReporter {
  void report(Object error);
}

class SnackBarErrorReporter implements ErrorReporter {
  const SnackBarErrorReporter();

  @override
  void report(Object error) => reportError(error);
}

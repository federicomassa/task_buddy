import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// True only on a real Android device/emulator — false on web, where
/// [Platform] isn't available at all, and false on other platforms.
bool get isAndroidPlatform => !kIsWeb && Platform.isAndroid;

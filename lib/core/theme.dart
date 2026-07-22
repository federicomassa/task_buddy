import 'package:flutter/material.dart';

ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorSchemeSeed: Colors.teal,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A modern Riverpod Notifier to handle the app's theme state.
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  /// Swaps the theme between Light and Dark
  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}

/// The provider we will watch in the UI
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
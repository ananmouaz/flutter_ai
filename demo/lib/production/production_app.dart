import 'package:flutter/material.dart';
import 'package:flutter_ai_demo/production/production_chat.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// Light theme shared by the recipe app and its tests.
ThemeData productionLightTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  colorSchemeSeed: const Color(0xFF0D0D0D),
  scaffoldBackgroundColor: Colors.white,
  extensions: [AiThemeExtension.fallback()],
);

/// Dark theme shared by the recipe app and its tests.
ThemeData productionDarkTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  brightness: Brightness.dark,
  colorSchemeSeed: const Color(0xFF8E8E96),
  scaffoldBackgroundColor: const Color(0xFF131316),
  extensions: [AiThemeExtension.dark()],
);

/// The production recipe as a standalone app that follows the system theme.
///
///   flutter run -t lib/main_production.dart
///   flutter run -t lib/main_production.dart --dart-define=RTL=true
class ProductionAgentApp extends StatelessWidget {
  /// Creates the app. [rtl] forces right-to-left layout for review.
  const ProductionAgentApp({super.key, this.rtl = false, this.home});

  /// Whether to lay the app out right-to-left.
  final bool rtl;

  /// Replaces the recipe screen (tests inject a faster provider).
  final Widget? home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flutter_ai production recipe',
    debugShowCheckedModeBanner: false,
    theme: productionLightTheme(),
    darkTheme: productionDarkTheme(),
    builder: rtl
        ? (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!)
        : null,
    home: home ?? const ProductionChatScreen(),
  );
}

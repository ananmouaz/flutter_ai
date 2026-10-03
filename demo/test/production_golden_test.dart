import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_demo/production/production_app.dart';
import 'package:flutter_ai_demo/production/production_chat.dart';
import 'package:flutter_ai_demo/production/production_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// Visual regression checks for the production recipe.
//
//   flutter test test/production_golden_test.dart              # compare
//   flutter test test/production_golden_test.dart --update-goldens
//
// Like capture_test.dart, these render with the SDK's real Roboto and
// MaterialIcons fonts, so they are platform-sensitive: they are verified on
// the macOS reference machine and are not run in CI.

const String _materialFonts =
    '/Users/mouaz/flutter-sdk/flutter/bin/cache/artifacts/material_fonts';
const String _monoFonts =
    '/Users/mouaz/flutter-sdk/flutter/bin/cache/dart-sdk/bin/resources/'
    'devtools/assets/fonts/Roboto_Mono';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

class _Variant {
  const _Variant(
    this.name, {
    this.size = const Size(390, 844),
    this.dark = false,
    this.rtl = false,
    this.textScale = 1,
    this.reduceMotion = false,
  });

  final String name;
  final Size size;
  final bool dark;
  final bool rtl;
  final double textScale;
  final bool reduceMotion;
}

Future<void> _pump(WidgetTester tester, _Variant v) async {
  tester.view
    ..physicalSize = v.size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: productionLightTheme(),
      darkTheme: productionDarkTheme(),
      themeMode: v.dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(v.textScale),
          disableAnimations: v.reduceMotion,
        ),
        child: Directionality(
          textDirection: v.rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
      ),
      home: ProductionChatScreen(
        provider: ProductionAgentProvider(
          delay: const Duration(milliseconds: 10),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _run(WidgetTester tester, [int ms = 2500]) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _ask(WidgetTester tester, String starter, [int ms = 2500]) async {
  await tester.tap(find.text(starter));
  await _run(tester, ms);
}

Future<void> _expectGolden(String name) => expectLater(
  find.byType(ProductionChatScreen),
  matchesGoldenFile('goldens/production_$name.png'),
);

void main() {
  setUpAll(() async {
    await _loadFont('Roboto', [
      '$_materialFonts/Roboto-Regular.ttf',
      '$_materialFonts/Roboto-Medium.ttf',
      '$_materialFonts/Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', [
      '$_materialFonts/MaterialIcons-Regular.otf',
    ]);
    // The task step counter uses codeStyle ('monospace').
    await _loadFont('monospace', [
      '$_monoFonts/RobotoMono-Regular.ttf',
      '$_monoFonts/RobotoMono-Medium.ttf',
    ]);
  });

  const variants = [
    _Variant('light'),
    _Variant('dark', dark: true),
    _Variant('rtl', rtl: true),
    _Variant('large_text_narrow', size: Size(320, 640), textScale: 2),
  ];

  for (final v in variants) {
    testWidgets('empty state — ${v.name}', (tester) async {
      await _pump(tester, v);
      await _expectGolden('empty_${v.name}');
    });

    testWidgets('settled answer — ${v.name}', (tester) async {
      await _pump(tester, v);
      await _ask(tester, productionStarters.first);
      await _expectGolden('answer_${v.name}');
    });
  }

  testWidgets('streaming progress — reduced motion', (tester) async {
    await _pump(tester, const _Variant('reduced', reduceMotion: true));
    await _ask(tester, productionStarters.first, 400);
    await _expectGolden('streaming_reduced_motion');
    await _run(tester); // let the scripted stream finish
  });

  testWidgets('approval awaiting', (tester) async {
    await _pump(tester, const _Variant('light'));
    await _ask(tester, 'Book a table for two tonight');
    await _expectGolden('approval_awaiting');
  });

  testWidgets('question answered with result card', (tester) async {
    await _pump(tester, const _Variant('light'));
    await _ask(tester, 'Remind me to renew my passport');
    await tester.tap(find.text('A month before'));
    await tester.pump();
    await tester.ensureVisible(find.text('Answer'));
    await tester.tap(find.text('Answer'));
    await _run(tester);
    await _expectGolden('result_card');
  });

  testWidgets('failed run with retry', (tester) async {
    await _pump(tester, const _Variant('light'));
    await _ask(tester, 'Check flight TP 1350');
    await _expectGolden('failed');
  });

  testWidgets('sources sheet', (tester) async {
    await _pump(tester, const _Variant('light'));
    await _ask(tester, productionStarters.first);
    final button = find.bySemanticsLabel('Show 4 sources');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/production_sources_sheet.png'),
    );
  });
}

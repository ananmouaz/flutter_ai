import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_demo/production/production_app.dart';
import 'package:flutter_ai_demo/production/production_chat.dart';
import 'package:flutter_ai_demo/production/production_provider.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

// Headless marketing screenshots of the production recipe design.
//
//   flutter test test/production_marketing_shots.dart --update-goldens
//
// Writes @3x PNGs into test/shots/prod_*.png (and GIF frames as
// prod_run_###.png). Some shots shrink the viewport to drop the empty space
// under a short conversation, keeping the composer pinned at the bottom. See
// demo/README.md for where each shot is copied.

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

const _phone = Size(402, 874);

Future<void> _pump(
  WidgetTester tester, {
  bool dark = false,
  Duration delay = const Duration(milliseconds: 10),
}) async {
  tester.view
    ..physicalSize = _phone * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: productionLightTheme(),
      darkTheme: productionDarkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: ProductionChatScreen(
        provider: ProductionAgentProvider(delay: delay),
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

/// Shrinks the viewport after the flow so the shot drops the empty space
/// under a short conversation (taps need the full phone first).
Future<void> _crop(WidgetTester tester, double height) async {
  tester.view.physicalSize = Size(_phone.width, height) * 3;
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _shoot(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('shots/prod_$name.png'),
);

void main() {
  setUpAll(() async {
    await _loadFont('Roboto', [
      '$_materialFonts/Roboto-Regular.ttf',
      '$_materialFonts/Roboto-Medium.ttf',
      '$_materialFonts/Roboto-Bold.ttf',
      '$_materialFonts/Roboto-Italic.ttf',
    ]);
    await _loadFont('MaterialIcons', [
      '$_materialFonts/MaterialIcons-Regular.otf',
    ]);
    await _loadFont('monospace', [
      '$_monoFonts/RobotoMono-Regular.ttf',
      '$_monoFonts/RobotoMono-Medium.ttf',
    ]);
  });

  testWidgets('empty state', (tester) async {
    await _pump(tester);
    await _shoot('empty_light');
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    testWidgets('settled answer — $theme', (tester) async {
      await _pump(tester, dark: dark);
      await _ask(tester, productionStarters.first);
      await _shoot('answer_$theme');
    });
  }

  testWidgets('streaming frames', (tester) async {
    await _pump(tester, delay: const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 300));
    await _shoot('run_000');
    await tester.tap(find.text(productionStarters.first));
    for (var i = 1; i < 56; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await _shoot('run_${i.toString().padLeft(3, '0')}');
    }
    await _run(tester, 4000);
  });

  testWidgets('streaming mid-answer', (tester) async {
    // Mid-run, with the step list open: the second tool is reading a page.
    await _pump(tester, delay: const Duration(milliseconds: 100));
    await _ask(tester, productionStarters.first, 900);
    await tester.tap(find.textContaining('Reading').first);
    await tester.pump(const Duration(milliseconds: 400));
    await _crop(tester, 560);
    await _shoot('streaming');
    await _run(tester, 8000); // let the scripted stream finish
  });

  testWidgets('question', (tester) async {
    await _pump(tester);
    await _ask(tester, 'Remind me to renew my passport');
    await tester.tap(find.text('A month before'));
    await _run(tester, 1000);
    await _crop(tester, 640);
    await _shoot('question');
  });

  testWidgets('result card', (tester) async {
    await _pump(tester);
    await _ask(tester, 'Remind me to renew my passport');
    await tester.tap(find.text('A month before'));
    await tester.pump();
    await tester.ensureVisible(find.text('Answer'));
    await tester.tap(find.text('Answer'));
    await _run(tester);
    await _crop(tester, 560);
    await _shoot('result_card');
  });

  testWidgets('approval', (tester) async {
    await _pump(tester);
    await _ask(tester, 'Book a table for two tonight');
    await _crop(tester, 560);
    await _shoot('approval');
  });

  testWidgets('failed run', (tester) async {
    await _pump(tester);
    await _ask(tester, 'Check flight TP 1350');
    await _crop(tester, 560);
    await _shoot('failed');
  });

  testWidgets('sources sheet', (tester) async {
    await _pump(tester);
    await _ask(tester, productionStarters.first);
    final button = find.bySemanticsLabel('Show 4 sources');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await _shoot('sources_sheet');
  });

  testWidgets('live voice', (tester) async {
    tester.view
      ..physicalSize = _phone * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: productionDarkTheme(),
        home: const Scaffold(
          backgroundColor: Color(0xFF000000),
          body: AiLiveSession(
            status: AiLiveStatus.listening,
            amplitude: 0.45,
            transcript: '"Compare weekend trains to Porto"',
            conversation: AiConversationView(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
              messages: [
                AiMessage(
                  id: 'u1',
                  role: AiRole.user,
                  parts: [TextPart('Compare weekend trains to Porto')],
                ),
                AiMessage(
                  id: 'a1',
                  role: AiRole.assistant,
                  parts: [
                    TextPart(
                      'The Alfa Pendular at 09:00 is fastest. The '
                      'Intercidades is cheapest, from €25.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 320));
    await _shoot('voice');
  });
}

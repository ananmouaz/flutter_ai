import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_demo/demo_data.dart';
import 'package:flutter_ai_demo/main.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

// Headless screenshot generation via golden capture.
//
//   flutter test test/capture_test.dart --update-goldens
//
// Writes one PNG per element plus a sequence of chat frames into
// test/shots/, rendered with the SDK's real Roboto + MaterialIcons fonts so
// text and icons appear (not the default test-font boxes).

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
    // codeStyle uses 'monospace'; load RobotoMono so it renders in goldens.
    await _loadFont('monospace', [
      '$_monoFonts/RobotoMono-Regular.ttf',
      '$_monoFonts/RobotoMono-Medium.ttf',
      '$_monoFonts/RobotoMono-Bold.ttf',
    ]);
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532); // iPhone-ish @3x
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets('element screenshots', (tester) async {
    const captureKey = ValueKey('capture');
    for (final item in galleryItems()) {
      await tester.pumpWidget(_card(item.child, captureKey));
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byKey(captureKey),
        matchesGoldenFile('shots/element_${item.name}.png'),
      );
    }
  });

  testWidgets('chat streaming frames', (tester) async {
    await tester.pumpWidget(const FlutterAiDemoApp());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Plan a weekend in Lisbon'));
    await tester.pump();

    for (var i = 0; i < 38; i++) {
      await tester.pump(const Duration(milliseconds: 130));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/chat_${i.toString().padLeft(3, '0')}.png'),
      );
    }
  });

  testWidgets('error state', (tester) async {
    await tester.pumpWidget(const FlutterAiDemoApp());
    await tester.pump(const Duration(milliseconds: 300));
    // Send via the composer (the "Trigger an error" chip may be off-screen).
    await tester.enterText(find.byType(TextField), 'trigger an error');
    await tester
        .pump(); // let the composer swap Live → Send now that text exists
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/chat_error.png'),
    );
  });

  testWidgets('dark mode preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF131316),
          splashFactory: NoSplash.splashFactory,
          extensions: [AiThemeExtension.dark()],
        ),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AiMessageBubble(
                    message: AiMessage(
                      id: 'u',
                      role: AiRole.user,
                      parts: [TextPart('Plan a weekend in Lisbon')],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const AiResponse(
                    text:
                        '## Day 1\n- Belém Tower & pastéis de nata\n'
                        '- Alfama and the castle\n\nSunny, **~24°C** — pack '
                        'light. See the [guide](https://x.test).',
                  ),
                  const Spacer(),
                  AiComposer(
                    onSend: (_) {},
                    onAttach: () {},
                    onVoice: () {},
                    onLive: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/dark_preview.png'),
    );
  });
}

/// Renders a single element inside a content-tight white card so the captured
/// PNG hugs the element instead of spanning the whole screen.
Widget _card(Widget child, Key key) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorSchemeSeed: const Color(0xFF6D28D9),
    scaffoldBackgroundColor: const Color(0xFFEDEBF3),
    splashFactory: NoSplash.splashFactory,
    extensions: [demoTheme],
  ),
  home: Scaffold(
    body: Center(
      child: RepaintBoundary(
        key: key,
        child: Container(
          width: 360,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  ),
);

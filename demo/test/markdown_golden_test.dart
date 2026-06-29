import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_demo/demo_data.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

// Golden coverage for the elements Markdown renderer (AiResponse /
// MarkdownTextRenderer). Lives under demo/ because goldens are platform-
// sensitive and CI only runs them here (it skips demo/), matching the
// convention in capture_test.dart.
//
//   flutter test test/markdown_golden_test.dart --update-goldens
//
// Renders with the SDK's real Roboto + MaterialIcons + RobotoMono fonts so
// text, list bullets, checkboxes, and code render (not test-font boxes).

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

  testWidgets('markdown renderer golden', (tester) async {
    const captureKey = ValueKey('capture');
    // One document covering the representative markdown features.
    const markdown =
        '# Heading 1\n'
        '## Heading 2\n\n'
        'Plain text with **bold**, *italic*, ~~strikethrough~~, and '
        '`inline code`.\n\n'
        'A [link to Flutter](https://flutter.dev).\n\n'
        '- First bullet\n'
        '- Second bullet\n'
        '- Third bullet\n\n'
        '1. Ordered one\n'
        '2. Ordered two\n\n'
        '- [x] Completed task\n'
        '- [ ] Pending task\n\n'
        '---\n\n'
        '> A blockquote with a thoughtful aside.\n\n'
        '```dart\n'
        'void main() {\n'
        "  print('hello');\n"
        '}\n'
        '```\n';

    await tester.pumpWidget(
      _card(const AiResponse(text: markdown), captureKey),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('shots/markdown_kitchen_sink.png'),
    );
  });
}

/// Renders the response inside a content-tight white card so the captured PNG
/// hugs the content. Mirrors capture_test.dart's `_card`.
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
      child: SingleChildScrollView(
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
  ),
);

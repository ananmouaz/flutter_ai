import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_demo/feature_sections.dart';
import 'package:flutter_ai_demo/main.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

// Headless marketing screenshots of the redesigned showcase app.
//
//   flutter test test/marketing_shots.dart --update-goldens
//
// Writes full-viewport PNGs of the hero (empty + streaming, light + dark) and
// each feature section into test/shots/marketing_*.png. Rendered with the real
// Roboto/MaterialIcons/RobotoMono fonts so type and icons appear.

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
    view.physicalSize = const Size(1206, 2622); // ~402x874 logical @3x
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
  });

  Future<void> shoot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/marketing_$name.png'),
    );
  }

  // Renders FeatureSections alone in a single scroll view (no nested chat
  // scrollable to fight), so each section can be brought into view cleanly.
  Widget sectionsApp({required bool dark}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          brightness: dark ? Brightness.dark : Brightness.light,
          scaffoldBackgroundColor:
              dark ? const Color(0xFF131316) : Colors.white,
          splashFactory: NoSplash.splashFactory,
          extensions: [dark ? AiThemeExtension.dark() : AiThemeExtension.fallback()],
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: FeatureSections(isWide: false, onOpenGallery: () {}),
            ),
          ),
        ),
      );

  Future<void> scrollTo(WidgetTester tester, String exactTitle) async {
    await tester.ensureVisible(find.text(exactTitle).first);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('hero — empty (light)', (tester) async {
    await tester.pumpWidget(const FlutterAiDemoApp());
    await tester.pump(const Duration(milliseconds: 350));
    await shoot(tester, '01_hero_empty_light');
  });

  testWidgets('hero — streaming (light)', (tester) async {
    await tester.pumpWidget(const FlutterAiDemoApp());
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Plan a weekend in Lisbon').first);
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 130));
    }
    await shoot(tester, '02_hero_streaming_light');
  });

  testWidgets('feature sections (light)', (tester) async {
    await tester.pumpWidget(sectionsApp(dark: false));
    await tester.pump(const Duration(milliseconds: 350));
    for (final (i, entry) in const [
      ('Streaming & Markdown', 'streaming'),
      ('Generative UI', 'genui'),
      ('Tool calling', 'tools'),
      ('Citations & grounding', 'citations'),
      ('Voice', 'voice'),
      ('Theming', 'theming'),
    ].indexed) {
      await scrollTo(tester, entry.$1);
      await shoot(tester, '1${i}_section_${entry.$2}');
    }
  });

  testWidgets('hero — dark', (tester) async {
    await tester.pumpWidget(const FlutterAiDemoApp());
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Plan a weekend in Lisbon').first);
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 130));
    }
    await shoot(tester, '20_hero_streaming_dark');
  });
}

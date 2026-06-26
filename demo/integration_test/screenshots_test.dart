import 'package:flutter/material.dart';
import 'package:flutter_ai_demo/demo_data.dart';
import 'package:flutter_ai_demo/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Captures a screenshot of every gallery element, then a sequence of frames of
/// the chat streaming a scripted response. Run via `flutter drive` with
/// test_driver/screenshot_driver.dart, which writes the PNGs to disk.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('element screenshots', (tester) async {
    for (final item in galleryItems()) {
      await tester.pumpWidget(_frame(item.child));
      // Fixed pump rather than pumpAndSettle: AiLoader animates forever, so
      // pumpAndSettle would never return.
      await tester.pump(const Duration(milliseconds: 350));
      await binding.takeScreenshot('element_${item.name}');
    }
  });

  testWidgets('chat streaming frames', (tester) async {
    await tester.pumpWidget(const FlutterAiDemoApp());
    await tester.pumpAndSettle();

    // Start a turn by tapping the first suggestion chip.
    await tester.tap(find.text("What's the weather in London?"));
    await tester.pump();

    for (var i = 0; i < 32; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 130));
      await tester.pump();
      await binding.takeScreenshot('chat_${i.toString().padLeft(3, '0')}');
    }
  });
}

Widget _frame(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6D28D9),
        scaffoldBackgroundColor: Colors.white,
        extensions: [demoTheme],
      ),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: SingleChildScrollView(child: child)),
          ),
        ),
      ),
    );

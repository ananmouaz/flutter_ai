import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// How an assistant message is laid out.
enum AiMessageStyle {
  /// Full-width text on the page, with no container — the modern AI-assistant
  /// look (ChatGPT / Claude / Gemini). The default.
  plain,

  /// Wrapped in a filled bubble, like a messaging app.
  bubble,
}

/// The design tokens that style every `flutter_ai_elements` widget.
///
/// Registered as a Flutter [ThemeExtension], so the components adopt any host
/// design system without being hardcoded to Material or Cupertino. Read it with
/// [AiThemeExtension.of]; override individual tokens via [copyWith]; or replace
/// it wholesale in `ThemeData.extensions`.
///
/// [AiThemeExtension.fallback] supplies a clean, modern default modeled on
/// current AI assistants: a near-monochrome palette, a **bubble-less** assistant
/// ([AiMessageStyle.plain]), a quiet user bubble, no shadows, and a solid
/// [accentColor] for actions. Re-theme it to anything, or swap message rendering
/// entirely via `AiChat`'s `messageBuilder`.
///
/// All visual constants for the package live behind this one extension, so a
/// future `flutter_ai_design_system` can lift them out without an API break.
@immutable
class AiThemeExtension extends ThemeExtension<AiThemeExtension> {
  /// Creates a theme extension. Prefer [AiThemeExtension.fallback] and
  /// [copyWith] for most cases.
  const AiThemeExtension({
    required this.assistantMessageStyle,
    required this.userBubbleColor,
    required this.assistantBubbleColor,
    required this.userTextColor,
    required this.assistantTextColor,
    required this.accentColor,
    required this.onAccentColor,
    required this.borderColor,
    required this.bubbleRadius,
    required this.bubbleShadow,
    required this.bubblePadding,
    required this.messageSpacing,
    required this.maxBubbleWidthFraction,
    required this.composerPadding,
    required this.textStyle,
    required this.codeStyle,
    required this.loaderColor,
    required this.motionDuration,
    required this.motionCurve,
    required this.enableHaptics,
  });

  /// The modern, near-monochrome default (light).
  factory AiThemeExtension.fallback() => const AiThemeExtension(
        assistantMessageStyle: AiMessageStyle.plain,
        userBubbleColor: Color(0xFFF4F4F4),
        assistantBubbleColor: Color(0xFFF7F7F8),
        userTextColor: Color(0xFF0D0D0D),
        assistantTextColor: Color(0xFF0D0D0D),
        accentColor: Color(0xFF0D0D0D),
        onAccentColor: Color(0xFFFFFFFF),
        borderColor: Color(0xFFE5E5E5),
        bubbleRadius: BorderRadius.all(Radius.circular(22)),
        bubbleShadow: [],
        bubblePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        messageSpacing: 18,
        maxBubbleWidthFraction: 0.80,
        composerPadding: EdgeInsets.fromLTRB(14, 8, 14, 12),
        textStyle: TextStyle(fontSize: 16.5, height: 1.5),
        codeStyle:
            TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.45),
        loaderColor: Color(0xFF8E8EA0),
        motionDuration: Duration(milliseconds: 240),
        motionCurve: Curves.easeOutCubic,
        enableHaptics: true,
      );

  /// How assistant messages are laid out (plain full-width vs. bubble).
  final AiMessageStyle assistantMessageStyle;

  /// Background of a user's message bubble.
  final Color userBubbleColor;

  /// Background of an assistant bubble (used when [assistantMessageStyle] is
  /// [AiMessageStyle.bubble]) and of the composer field.
  final Color assistantBubbleColor;

  /// Text color inside a user bubble.
  final Color userTextColor;

  /// Text color for assistant content.
  final Color assistantTextColor;

  /// Solid accent for primary actions (the send button, etc.).
  final Color accentColor;

  /// Foreground drawn on top of [accentColor].
  final Color onAccentColor;

  /// Hairline/border color for fields, cards, and dividers.
  final Color borderColor;

  /// Corner radius of bubbles and the composer field.
  final BorderRadius bubbleRadius;

  /// Shadow cast by bubbles. Empty by default (flat).
  final List<BoxShadow> bubbleShadow;

  /// Inner padding of a message bubble.
  final EdgeInsets bubblePadding;

  /// Vertical gap between consecutive messages.
  final double messageSpacing;

  /// Maximum width of a *bubble* as a fraction of available width (`0`–`1`).
  /// Plain assistant messages always span the full width.
  final double maxBubbleWidthFraction;

  /// Padding around the composer.
  final EdgeInsets composerPadding;

  /// Base text style for message prose.
  final TextStyle textStyle;

  /// Text style for code spans and blocks.
  final TextStyle codeStyle;

  /// Color of the thinking/typing loader.
  final Color loaderColor;

  /// Duration for entrance and state-change animations.
  final Duration motionDuration;

  /// Curve for entrance and state-change animations.
  final Curve motionCurve;

  /// Whether widgets emit haptic feedback on key interactions.
  final bool enableHaptics;

  /// Returns the extension from [context], or [AiThemeExtension.fallback] if no
  /// theme provides one.
  static AiThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<AiThemeExtension>() ??
      AiThemeExtension.fallback();

  @override
  AiThemeExtension copyWith({
    AiMessageStyle? assistantMessageStyle,
    Color? userBubbleColor,
    Color? assistantBubbleColor,
    Color? userTextColor,
    Color? assistantTextColor,
    Color? accentColor,
    Color? onAccentColor,
    Color? borderColor,
    BorderRadius? bubbleRadius,
    List<BoxShadow>? bubbleShadow,
    EdgeInsets? bubblePadding,
    double? messageSpacing,
    double? maxBubbleWidthFraction,
    EdgeInsets? composerPadding,
    TextStyle? textStyle,
    TextStyle? codeStyle,
    Color? loaderColor,
    Duration? motionDuration,
    Curve? motionCurve,
    bool? enableHaptics,
  }) =>
      AiThemeExtension(
        assistantMessageStyle:
            assistantMessageStyle ?? this.assistantMessageStyle,
        userBubbleColor: userBubbleColor ?? this.userBubbleColor,
        assistantBubbleColor: assistantBubbleColor ?? this.assistantBubbleColor,
        userTextColor: userTextColor ?? this.userTextColor,
        assistantTextColor: assistantTextColor ?? this.assistantTextColor,
        accentColor: accentColor ?? this.accentColor,
        onAccentColor: onAccentColor ?? this.onAccentColor,
        borderColor: borderColor ?? this.borderColor,
        bubbleRadius: bubbleRadius ?? this.bubbleRadius,
        bubbleShadow: bubbleShadow ?? this.bubbleShadow,
        bubblePadding: bubblePadding ?? this.bubblePadding,
        messageSpacing: messageSpacing ?? this.messageSpacing,
        maxBubbleWidthFraction:
            maxBubbleWidthFraction ?? this.maxBubbleWidthFraction,
        composerPadding: composerPadding ?? this.composerPadding,
        textStyle: textStyle ?? this.textStyle,
        codeStyle: codeStyle ?? this.codeStyle,
        loaderColor: loaderColor ?? this.loaderColor,
        motionDuration: motionDuration ?? this.motionDuration,
        motionCurve: motionCurve ?? this.motionCurve,
        enableHaptics: enableHaptics ?? this.enableHaptics,
      );

  @override
  AiThemeExtension lerp(covariant AiThemeExtension? other, double t) {
    if (other == null) return this;
    return AiThemeExtension(
      assistantMessageStyle:
          t < 0.5 ? assistantMessageStyle : other.assistantMessageStyle,
      userBubbleColor: Color.lerp(userBubbleColor, other.userBubbleColor, t)!,
      assistantBubbleColor:
          Color.lerp(assistantBubbleColor, other.assistantBubbleColor, t)!,
      userTextColor: Color.lerp(userTextColor, other.userTextColor, t)!,
      assistantTextColor:
          Color.lerp(assistantTextColor, other.assistantTextColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      onAccentColor: Color.lerp(onAccentColor, other.onAccentColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      bubbleRadius: BorderRadius.lerp(bubbleRadius, other.bubbleRadius, t)!,
      bubbleShadow: BoxShadow.lerpList(bubbleShadow, other.bubbleShadow, t) ??
          bubbleShadow,
      bubblePadding: EdgeInsets.lerp(bubblePadding, other.bubblePadding, t)!,
      messageSpacing: lerpDouble(messageSpacing, other.messageSpacing, t)!,
      maxBubbleWidthFraction: lerpDouble(
        maxBubbleWidthFraction,
        other.maxBubbleWidthFraction,
        t,
      )!,
      composerPadding:
          EdgeInsets.lerp(composerPadding, other.composerPadding, t)!,
      textStyle: TextStyle.lerp(textStyle, other.textStyle, t)!,
      codeStyle: TextStyle.lerp(codeStyle, other.codeStyle, t)!,
      loaderColor: Color.lerp(loaderColor, other.loaderColor, t)!,
      motionDuration: t < 0.5 ? motionDuration : other.motionDuration,
      motionCurve: t < 0.5 ? motionCurve : other.motionCurve,
      enableHaptics: t < 0.5 ? enableHaptics : other.enableHaptics,
    );
  }
}

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// The design tokens that style every `flutter_ai_elements` widget.
///
/// Registered as a Flutter [ThemeExtension], so the components adopt any host
/// design system without being hardcoded to Material or Cupertino. Read it with
/// [AiThemeExtension.of]; override individual tokens via [copyWith]; or replace
/// it wholesale in `ThemeData.extensions`.
///
/// [AiThemeExtension.fallback] supplies a mobile-first default — soft pill
/// shapes, ambient (not harsh) shadows, generous touch padding, and spring-like
/// motion — that works without any other theme configuration.
///
/// All visual constants for the package live behind this one extension, so a
/// future `flutter_ai_design_system` can lift them out without an API break.
@immutable
class AiThemeExtension extends ThemeExtension<AiThemeExtension> {
  /// Creates a theme extension. Prefer [AiThemeExtension.fallback] and
  /// [copyWith] for most cases.
  const AiThemeExtension({
    required this.userBubbleColor,
    required this.assistantBubbleColor,
    required this.userTextColor,
    required this.assistantTextColor,
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

  /// The mobile-first default theme (light).
  factory AiThemeExtension.fallback() => const AiThemeExtension(
        userBubbleColor: Color(0xFF2563EB),
        assistantBubbleColor: Color(0xFFF1F1F4),
        userTextColor: Color(0xFFFFFFFF),
        assistantTextColor: Color(0xFF18181B),
        bubbleRadius: BorderRadius.all(Radius.circular(20)),
        bubbleShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        bubblePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        messageSpacing: 10,
        maxBubbleWidthFraction: 0.82,
        composerPadding: EdgeInsets.all(12),
        textStyle: TextStyle(fontSize: 16, height: 1.4),
        codeStyle:
            TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.4),
        loaderColor: Color(0xFF8A8A8E),
        motionDuration: Duration(milliseconds: 240),
        motionCurve: Curves.easeOutCubic,
        enableHaptics: true,
      );

  /// Background of a user's message bubble.
  final Color userBubbleColor;

  /// Background of an assistant's message bubble.
  final Color assistantBubbleColor;

  /// Text color inside a user bubble.
  final Color userTextColor;

  /// Text color inside an assistant bubble.
  final Color assistantTextColor;

  /// Corner radius of message bubbles.
  final BorderRadius bubbleRadius;

  /// Ambient shadow cast by message bubbles.
  final List<BoxShadow> bubbleShadow;

  /// Inner padding of a message bubble.
  final EdgeInsets bubblePadding;

  /// Vertical gap between consecutive messages.
  final double messageSpacing;

  /// Maximum bubble width as a fraction of the available width (`0`–`1`).
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
    Color? userBubbleColor,
    Color? assistantBubbleColor,
    Color? userTextColor,
    Color? assistantTextColor,
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
        userBubbleColor: userBubbleColor ?? this.userBubbleColor,
        assistantBubbleColor: assistantBubbleColor ?? this.assistantBubbleColor,
        userTextColor: userTextColor ?? this.userTextColor,
        assistantTextColor: assistantTextColor ?? this.assistantTextColor,
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
      userBubbleColor: Color.lerp(userBubbleColor, other.userBubbleColor, t)!,
      assistantBubbleColor:
          Color.lerp(assistantBubbleColor, other.assistantBubbleColor, t)!,
      userTextColor: Color.lerp(userTextColor, other.userTextColor, t)!,
      assistantTextColor:
          Color.lerp(assistantTextColor, other.assistantTextColor, t)!,
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
      // Discrete tokens snap at the midpoint.
      motionDuration: t < 0.5 ? motionDuration : other.motionDuration,
      motionCurve: t < 0.5 ? motionCurve : other.motionCurve,
      enableHaptics: t < 0.5 ? enableHaptics : other.enableHaptics,
    );
  }
}

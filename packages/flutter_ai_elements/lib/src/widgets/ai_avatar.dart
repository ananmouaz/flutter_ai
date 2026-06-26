import 'package:flutter/material.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A small circular avatar identifying a message's author.
///
/// Colors derive from the active [AiThemeExtension]; override the icon per role.
class AiAvatar extends StatelessWidget {
  /// Creates an avatar for [role].
  const AiAvatar({
    super.key,
    required this.role,
    this.size = 32,
    this.userIcon = Icons.person_outline,
    this.assistantIcon = Icons.auto_awesome,
  });

  /// The author whose avatar to show.
  final AiRole role;

  /// Diameter of the avatar.
  final double size;

  /// Icon for user/system messages.
  final IconData userIcon;

  /// Icon for assistant/tool messages.
  final IconData assistantIcon;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final isUser = role == AiRole.user || role == AiRole.system;
    final background =
        isUser ? theme.userBubbleColor : theme.assistantBubbleColor;
    final foreground = isUser ? theme.userTextColor : theme.assistantTextColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(
        isUser ? userIcon : assistantIcon,
        size: size * 0.56,
        color: foreground,
      ),
    );
  }
}

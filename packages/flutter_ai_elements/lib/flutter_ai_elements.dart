/// Composable, themeable Flutter UI for AI chat.
///
/// Adopts the Vercel AI Elements component vocabulary while rendering through a
/// mobile-first `AiThemeExtension` — no shadcn or forui dependency. Built from
/// base Flutter widgets so any design system can restyle it via theme tokens.
///
/// ### Presentational vs. bound widgets
///
/// - **Presentational** (`AiMessageBubble`, `AiConversationView`, `AiComposer`,
///   `AiLoader`) take plain data and callbacks; reusable and easy to test.
/// - **Bound** (`AiConversation`, `AiPromptInput`) wire those to a
///   `UseChatController` from `flutter_ai_client` for a drop-in chat surface.
///
/// Re-exports `flutter_ai_client` (and transitively `flutter_ai_core`) so a
/// single import provides the controller, models, and UI.
library;

export 'package:flutter_ai_client/flutter_ai_client.dart';

export 'src/rendering/ai_text_renderer.dart';
export 'src/theme/ai_theme_extension.dart';
export 'src/widgets/ai_attachment.dart';
export 'src/widgets/ai_chat.dart';
export 'src/widgets/ai_composer.dart';
export 'src/widgets/ai_conversation_view.dart';
export 'src/widgets/ai_loader.dart';
export 'src/widgets/ai_message_bubble.dart';
export 'src/widgets/ai_prompt_input.dart';
export 'src/widgets/ai_reasoning.dart';
export 'src/widgets/ai_tool_group.dart';
export 'src/widgets/ai_tool_invocation.dart';

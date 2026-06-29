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
/// - **Bound** (`AiChat`, `AiPromptInput`) wire those to a
///   `UseChatController` from `flutter_ai_client` for a drop-in chat surface.
///
/// Re-exports `flutter_ai_client` (and transitively `flutter_ai_core`) so a
/// single import provides the controller, models, and UI.
library;

export 'package:flutter_ai_client/flutter_ai_client.dart';

export 'src/generative_ui/ai_widget_registry.dart';
export 'src/l10n/ai_localizations.dart';
export 'src/rendering/ai_text_renderer.dart';
export 'src/theme/ai_theme_extension.dart';
export 'src/widgets/ai_animated_response.dart';
export 'src/widgets/ai_attachment.dart';
export 'src/widgets/ai_avatar.dart';
export 'src/widgets/ai_branch.dart';
export 'src/widgets/ai_chain_of_thought.dart';
export 'src/widgets/ai_chat.dart';
export 'src/widgets/ai_chat_view.dart';
export 'src/widgets/ai_code_block.dart';
export 'src/widgets/ai_composer.dart';
export 'src/widgets/ai_confirmation.dart';
export 'src/widgets/ai_context_meter.dart';
export 'src/widgets/ai_conversation_list.dart';
export 'src/widgets/ai_conversation_view.dart';
export 'src/widgets/ai_empty_state.dart';
export 'src/widgets/ai_error_banner.dart';
export 'src/widgets/ai_image.dart';
export 'src/widgets/ai_inline_citation.dart';
export 'src/widgets/ai_live_session.dart';
export 'src/widgets/ai_loader.dart';
export 'src/widgets/ai_message_actions.dart';
export 'src/widgets/ai_message_bubble.dart';
export 'src/widgets/ai_model_selector.dart';
export 'src/widgets/ai_orb.dart';
export 'src/widgets/ai_prompt_input.dart';
export 'src/widgets/ai_reasoning.dart';
export 'src/widgets/ai_response.dart';
export 'src/widgets/ai_shimmer.dart';
export 'src/widgets/ai_sources.dart';
export 'src/widgets/ai_suggestions.dart';
export 'src/widgets/ai_task.dart';
export 'src/widgets/ai_tool_group.dart';
export 'src/widgets/ai_tool_invocation.dart';

import 'package:flutter/widgets.dart';

/// The user-facing strings used by `flutter_ai_elements` widgets.
///
/// Defaults are English. To translate, provide an [AiLocalizations] (or a
/// per-locale [AiLocalizationsDelegate]) through `MaterialApp.localizationsDelegates`:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: const [
///     AiLocalizationsDelegate(AiLocalizations(copy: 'Copier', send: 'Envoyer')),
///     ...GlobalMaterialLocalizations.delegates,
///   ],
/// );
/// ```
///
/// Widgets read these via [AiLocalizations.of], which falls back to the English
/// defaults when none is provided.
@immutable
class AiLocalizations {
  /// Creates a set of strings (English by default).
  const AiLocalizations({
    this.copy = 'Copy',
    this.regenerate = 'Regenerate',
    this.edit = 'Edit',
    this.readAloud = 'Read aloud',
    this.share = 'Share',
    this.goodResponse = 'Good response',
    this.badResponse = 'Bad response',
    this.stop = 'Stop',
    this.send = 'Send',
    this.live = 'Live',
    this.attach = 'Attach',
    this.dictate = 'Dictate',
    this.delete = 'Delete',
    this.dismiss = 'Dismiss',
    this.retry = 'Retry',
    this.close = 'Close',
    this.newChat = 'New chat',
    this.previousVersion = 'Previous version',
    this.nextVersion = 'Next version',
    this.scrollToLatest = 'Scroll to latest',
    this.messageHint = 'Message',
  });

  /// Copy-to-clipboard action.
  final String copy;

  /// Regenerate-response action.
  final String regenerate;

  /// Edit-message action.
  final String edit;

  /// Read-aloud (TTS) action.
  final String readAloud;

  /// Share action.
  final String share;

  /// Thumbs-up action.
  final String goodResponse;

  /// Thumbs-down action.
  final String badResponse;

  /// Stop-generation action.
  final String stop;

  /// Send-message action.
  final String send;

  /// Start-live-voice action.
  final String live;

  /// Attach-file action.
  final String attach;

  /// Start-dictation (mic) action.
  final String dictate;

  /// Delete action.
  final String delete;

  /// Dismiss action (e.g. error banner).
  final String dismiss;

  /// Retry action.
  final String retry;

  /// Close action (e.g. full-screen image).
  final String close;

  /// New-conversation action.
  final String newChat;

  /// Previous-branch navigation label.
  final String previousVersion;

  /// Next-branch navigation label.
  final String nextVersion;

  /// Scroll-to-latest button label.
  final String scrollToLatest;

  /// Composer placeholder text.
  final String messageHint;

  /// The nearest [AiLocalizations], or the English defaults if none is provided.
  static AiLocalizations of(BuildContext context) =>
      Localizations.of<AiLocalizations>(context, AiLocalizations) ??
      const AiLocalizations();

  /// A delegate serving the English defaults. Wrap your own
  /// [AiLocalizations] with [AiLocalizationsDelegate] to translate.
  static const LocalizationsDelegate<AiLocalizations> delegate =
      AiLocalizationsDelegate();
}

/// Serves a fixed [AiLocalizations] instance. Provide a translated instance to
/// localize, or implement your own delegate to switch by locale.
class AiLocalizationsDelegate extends LocalizationsDelegate<AiLocalizations> {
  /// Creates a delegate serving [strings] (English defaults if omitted).
  const AiLocalizationsDelegate([this.strings = const AiLocalizations()]);

  /// The strings this delegate serves.
  final AiLocalizations strings;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AiLocalizations> load(Locale locale) async => strings;

  @override
  bool shouldReload(AiLocalizationsDelegate old) =>
      !identical(old.strings, strings);
}

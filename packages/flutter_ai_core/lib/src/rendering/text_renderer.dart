/// A strategy for turning message text into a rendered representation.
///
/// Declared in the core — without a Flutter dependency — so models and contracts
/// can reference the seam, while UI packages provide the concrete widget-
/// producing implementation (the default in `flutter_ai_elements` is a
/// dependency-free Markdown renderer). Hosts inject a custom [TextRenderer] to
/// swap in their own parser or to support dialects such as LaTeX or custom tags.
///
/// The type parameter [T] is the rendered output — a `Widget` in the UI layer,
/// or any representation in non-UI contexts (tests, server-side rendering).
abstract interface class TextRenderer<T> {
  /// Renders [text] into a [T].
  ///
  /// [isStreaming] is `true` while the text is still arriving, letting an
  /// implementation defer expensive parsing or suppress live-region semantics
  /// until generation completes.
  T render(String text, {required bool isStreaming});
}

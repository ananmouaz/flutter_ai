import 'package:flutter/widgets.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Builds a widget for a [DataPart]'s payload.
typedef AiDataWidgetBuilder = Widget Function(
  BuildContext context,
  Map<String, Object?> data,
);

/// A name→widget allowlist for **generative UI**: the model emits a [DataPart]
/// with a `dataType` discriminator and a JSON payload, and the registry maps it
/// to a Flutter widget.
///
/// This is a deliberate allowlist — only registered `dataType`s render (no
/// reflection, no arbitrary instantiation), so a model can't conjure UI you
/// didn't sanction. Unknown types fall back (see [AiDataView]).
class AiWidgetRegistry {
  /// Creates a registry, optionally seeded with [builders].
  AiWidgetRegistry([Map<String, AiDataWidgetBuilder>? builders])
      : _builders = {...?builders};

  final Map<String, AiDataWidgetBuilder> _builders;

  /// Registers [builder] for [dataType], replacing any previous entry. Returns
  /// the registry for chaining.
  AiWidgetRegistry register(String dataType, AiDataWidgetBuilder builder) {
    _builders[dataType] = builder;
    return this;
  }

  /// Whether a builder is registered for [dataType].
  bool contains(String dataType) => _builders.containsKey(dataType);

  /// The `dataType`s with a registered builder.
  Iterable<String> get types => _builders.keys;

  /// Builds the widget for [part], or `null` if its `dataType` is not
  /// registered.
  Widget? build(BuildContext context, DataPart part) =>
      _builders[part.dataType]?.call(context, part.data);
}

/// Renders a [DataPart] via a [registry], showing [fallback] (or nothing) when
/// the part's `dataType` is not registered.
class AiDataView extends StatelessWidget {
  /// Creates a view for [part].
  const AiDataView({
    super.key,
    required this.part,
    required this.registry,
    this.fallback,
  });

  /// The structured part to render.
  final DataPart part;

  /// The allowlist of `dataType`→widget builders.
  final AiWidgetRegistry registry;

  /// Shown when [part]'s `dataType` is not registered. Defaults to an empty box.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) =>
      registry.build(context, part) ?? fallback ?? const SizedBox.shrink();
}

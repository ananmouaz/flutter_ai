import 'package:flutter_ai_tools/src/tool_spec.dart';

/// A single web-search hit.
final class SearchResult {
  /// Creates a search result.
  const SearchResult({required this.title, required this.url, this.snippet});

  /// Reconstructs a [SearchResult] from [json].
  factory SearchResult.fromJson(Map<String, Object?> json) => SearchResult(
        title: json['title']! as String,
        url: Uri.parse(json['url']! as String),
        snippet: json['snippet'] as String?,
      );

  /// The result's title.
  final String title;

  /// The result's location.
  final Uri url;

  /// A short snippet/summary, if available.
  final String? snippet;

  /// Serializes this result.
  Map<String, Object?> toJson() => {
        'title': title,
        'url': url.toString(),
        if (snippet != null) 'snippet': snippet,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchResult &&
          other.title == title &&
          other.url == url &&
          other.snippet == snippet);

  @override
  int get hashCode => Object.hash(title, url, snippet);

  @override
  String toString() => 'SearchResult($title, $url)';
}

/// A backend that performs web searches (Tavily, Brave, SerpAPI, a custom
/// endpoint, …). Host apps provide the implementation; this package only knows
/// the contract.
abstract interface class WebSearchAdapter {
  /// Returns up to [maxResults] hits for [query]; `null` lets the adapter pick
  /// its own limit.
  Future<List<SearchResult>> search(String query, {int? maxResults});
}

/// Builds a [ToolSpec] that exposes [adapter] to the model as a callable tool.
///
/// The tool takes a `query` string and returns `{ "results": [...] }`, where
/// each entry is a serialized [SearchResult]. Map those into `SourcePart`s in
/// your UI to render citations.
ToolSpec webSearchTool(
  WebSearchAdapter adapter, {
  String name = 'web_search',
  String description = 'Search the web for up-to-date information.',
  int maxResults = 5,
}) {
  return ToolSpec(
    name: name,
    description: description,
    parametersSchema: const {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'The search query.',
        },
      },
      'required': ['query'],
    },
    execute: (args) async {
      final query = (args['query'] as String?)?.trim() ?? '';
      if (query.isEmpty) {
        return {'results': <Object?>[]};
      }
      final results = await adapter.search(query, maxResults: maxResults);
      return {
        'results': [for (final result in results) result.toJson()],
      };
    },
  );
}

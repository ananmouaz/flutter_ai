import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart' as http;

/// The default HTTP client on the web: a [FetchClient] backed by the streaming
/// Fetch API, so SSE tokens arrive progressively.
///
/// The `http.Client()` default resolves to `BrowserClient` on the web, which is
/// XHR-backed and buffers the entire response body before the stream emits —
/// silently degrading token-by-token streaming to all-at-once. `FetchClient`
/// reads the response `ReadableStream` incrementally, restoring real streaming.
http.Client createDefaultHttpClient() => FetchClient(mode: RequestMode.cors);

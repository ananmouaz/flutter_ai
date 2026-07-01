import 'package:http/http.dart' as http;

/// The default HTTP client on native platforms: a standard [http.Client],
/// which already delivers a streamed response body chunk-by-chunk.
http.Client createDefaultHttpClient() => http.Client();

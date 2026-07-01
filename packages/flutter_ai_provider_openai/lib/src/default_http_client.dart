// Provides `createDefaultHttpClient`, resolved per-platform via conditional
// import so streaming works everywhere.
export 'default_http_client_io.dart'
    if (dart.library.js_interop) 'default_http_client_web.dart';

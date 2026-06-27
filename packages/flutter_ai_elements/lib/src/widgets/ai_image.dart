import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// Displays an AI-generated (or attached) image with rounded corners, a loading
/// placeholder, an error fallback, and tap-to-zoom into a full-screen,
/// pinch-zoomable viewer.
///
/// Provide inline [bytes] or a remote [url].
class AiImage extends StatelessWidget {
  /// Creates an image from inline [bytes] or a remote [url].
  const AiImage({
    super.key,
    this.bytes,
    this.url,
    this.aspectRatio = 1,
    this.enableZoom = true,
  }) : assert(bytes != null || url != null, 'Provide bytes or url');

  /// Inline image bytes.
  final Uint8List? bytes;

  /// Remote image location.
  final Uri? url;

  /// Aspect ratio of the inline preview.
  final double aspectRatio;

  /// Whether tapping opens a full-screen zoomable viewer.
  final bool enableZoom;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final image = _image(fit: BoxFit.cover);

    return GestureDetector(
      onTap: enableZoom ? () => _openViewer(context) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: DecoratedBox(
            decoration: BoxDecoration(color: theme.assistantBubbleColor),
            child: image,
          ),
        ),
      ),
    );
  }

  Image _image({required BoxFit fit}) {
    if (bytes != null) {
      return Image.memory(bytes!, fit: fit, errorBuilder: _error);
    }
    return Image.network(
      url!.toString(),
      fit: fit,
      errorBuilder: _error,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  Widget _error(BuildContext context, Object error, StackTrace? stack) =>
      const Center(child: Icon(Icons.broken_image_outlined, size: 32));

  void _openViewer(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (context, _, __) =>
              _FullScreenImage(child: _image(fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: child),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

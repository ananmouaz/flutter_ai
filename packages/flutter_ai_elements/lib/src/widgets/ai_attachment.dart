import 'package:flutter/material.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';

/// A compact preview of a [FilePart] attachment.
///
/// Images (with inline bytes or a URL) render as a rounded thumbnail; everything
/// else renders as a labeled file chip. Document text extraction is out of scope
/// — that belongs to a backend, off the UI thread.
class AiAttachment extends StatelessWidget {
  /// Creates an attachment preview for [file].
  const AiAttachment({
    super.key,
    required this.file,
    this.maxImageHeight = 200,
  });

  /// The file to preview.
  final FilePart file;

  /// Maximum height for image previews.
  final double maxImageHeight;

  bool get _isImage => file.mediaType.startsWith('image/');

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      final image = _buildImage();
      if (image != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxImageHeight),
            child: image,
          ),
        );
      }
    }
    return _FileChip(label: file.name ?? file.mediaType);
  }

  Widget? _buildImage() {
    final bytes = file.bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, errorBuilder: _onError);
    }
    final url = file.url;
    if (url != null) {
      return Image.network(
        url.toString(),
        fit: BoxFit.cover,
        errorBuilder: _onError,
      );
    }
    return null;
  }

  Widget _onError(BuildContext context, Object error, StackTrace? stack) =>
      _FileChip(label: file.name ?? file.mediaType);
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (color ?? const Color(0xFF000000)).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

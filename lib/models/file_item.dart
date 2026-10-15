import 'dart:typed_data';

/// Represents the conversion state of a queued file.
enum FileStatus { ready, converting, done, error }

/// All supported output formats.
enum OutputFormat {
  jpg('JPG', 'jpg', 'image'),
  png('PNG', 'png', 'image'),
  webp('WEBP', 'webp', 'image'),
  pdf('PDF', 'pdf', 'document'),
  gif('GIF', 'gif', 'image');

  const OutputFormat(this.label, this.extension, this.category);
  final String label;
  final String extension;
  final String category;
}

/// Maps an input file extension to valid output formats.
const Map<String, List<OutputFormat>> kSupportedConversions = {
  'jpg':  [OutputFormat.png, OutputFormat.webp, OutputFormat.pdf],
  'jpeg': [OutputFormat.png, OutputFormat.webp, OutputFormat.pdf],
  'png':  [OutputFormat.jpg, OutputFormat.webp, OutputFormat.pdf],
  'webp': [OutputFormat.jpg, OutputFormat.png, OutputFormat.pdf],
  'gif':  [OutputFormat.jpg, OutputFormat.png, OutputFormat.pdf],
  'bmp':  [OutputFormat.jpg, OutputFormat.png, OutputFormat.pdf],
  'tiff': [OutputFormat.jpg, OutputFormat.png, OutputFormat.pdf],
  'tif':  [OutputFormat.jpg, OutputFormat.png, OutputFormat.pdf],
};

/// A file that has been added to the FluxShare workspace.
class FileItem {
  final String id;
  final String originalName;
  final Uint8List originalBytes;
  final String originalFormat; // lowercase extension, e.g. 'png'

  OutputFormat targetFormat;
  Uint8List? convertedBytes;
  FileStatus status;
  String? errorMessage;
  String? blobUrl; // session-scoped blob URL for local download/share

  // ── Phase 2: Cloud Sharing & Firebase Metadata ──
  String? cloudDownloadUrl;
  bool isUploadedToCloud;
  bool isUploadingToCloud;
  double uploadProgress;
  DateTime? expiresAt;

  FileItem({
    required this.id,
    required this.originalName,
    required this.originalBytes,
    required this.originalFormat,
    required this.targetFormat,
    this.convertedBytes,
    this.status = FileStatus.ready,
    this.errorMessage,
    this.blobUrl,
    this.cloudDownloadUrl,
    this.isUploadedToCloud = false,
    this.isUploadingToCloud = false,
    this.uploadProgress = 0.0,
    this.expiresAt,
  });

  /// The active URL to share: prefers persistent Cloud URL, falls back to session Blob URL.
  String? get shareableUrl => cloudDownloadUrl ?? blobUrl;

  /// Human-readable file size string.
  String get formattedSize {
    final bytes = convertedBytes?.length ?? originalBytes.length;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  String get outputFileName {
    final base = originalName.contains('.')
        ? originalName.substring(0, originalName.lastIndexOf('.'))
        : originalName;
    return '$base.${targetFormat.extension}';
  }

  bool get isImage => ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif']
      .contains(originalFormat);

  List<OutputFormat> get availableFormats =>
      kSupportedConversions[originalFormat] ?? [];
}

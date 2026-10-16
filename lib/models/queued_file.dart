import 'dart:typed_data';

import 'file_formats.dart';

enum FileJobStatus { uploading, converting, ready, error }

class QueuedFile {
  const QueuedFile({
    required this.id,
    required this.originalName,
    required this.bytes,
    required this.family,
    required this.output,
    required this.status,
    this.progress = 0,
    this.convertedBytes,
    this.convertedName,
    this.errorMessage,
    this.quality = 85,
    this.maxWidth,
    this.maxHeight,
    this.shareUrl,
    this.selected = false,
  });

  final String id;
  final String originalName;
  final Uint8List bytes;
  final ConversionFamily family;
  final OutputFormat output;
  final FileJobStatus status;
  final double progress;
  final Uint8List? convertedBytes;
  final String? convertedName;
  final String? errorMessage;
  final int quality;
  final int? maxWidth;
  final int? maxHeight;
  final String? shareUrl;
  final bool selected;

  int get size => bytes.length;
  int get convertedSize => convertedBytes?.length ?? 0;

  QueuedFile copyWith({
    OutputFormat? output,
    FileJobStatus? status,
    double? progress,
    Uint8List? convertedBytes,
    String? convertedName,
    String? errorMessage,
    int? quality,
    int? maxWidth,
    int? maxHeight,
    String? shareUrl,
    bool? selected,
    bool clearError = false,
    bool clearShare = false,
    bool clearConverted = false,
  }) {
    return QueuedFile(
      id: id,
      originalName: originalName,
      bytes: bytes,
      family: family,
      output: output ?? this.output,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      convertedBytes: clearConverted ? null : (convertedBytes ?? this.convertedBytes),
      convertedName: clearConverted ? null : (convertedName ?? this.convertedName),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      quality: quality ?? this.quality,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      shareUrl: clearShare ? null : (shareUrl ?? this.shareUrl),
      selected: selected ?? this.selected,
    );
  }
}

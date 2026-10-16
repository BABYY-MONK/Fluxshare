import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluxshare/models/file_formats.dart';
import 'package:fluxshare/models/queued_file.dart';

void main() {
  test('copyWith clears converted output, errors, and share links on request', () {
    final file = QueuedFile(
      id: 'id',
      originalName: 'photo.png',
      bytes: Uint8List.fromList([1]),
      family: ConversionFamily.image,
      output: OutputFormat.jpg,
      status: FileJobStatus.error,
      convertedBytes: Uint8List.fromList([2]),
      convertedName: 'photo.jpg',
      errorMessage: 'old error',
      shareUrl: 'https://example.test/?share=id',
    );

    final updated = file.copyWith(
      status: FileJobStatus.ready,
      clearConverted: true,
      clearError: true,
      clearShare: true,
    );

    expect(updated.status, FileJobStatus.ready);
    expect(updated.convertedBytes, isNull);
    expect(updated.convertedName, isNull);
    expect(updated.errorMessage, isNull);
    expect(updated.shareUrl, isNull);
    expect(updated.bytes, file.bytes);
  });
}

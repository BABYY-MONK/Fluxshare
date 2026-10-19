import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluxshare/services/file_tools_service.dart';
import 'package:fluxshare/services/video_download_service.dart';

void main() {
  test('ZIP tool returns a valid archive and avoids duplicate names', () {
    final bytes = FileToolsService().createZip([
      (name: r'C:\private\notes.txt', bytes: Uint8List.fromList([1, 2, 3])),
      (name: 'notes.txt', bytes: Uint8List.fromList([4, 5])),
    ]);

    expect(bytes.take(2).toList(), [0x50, 0x4b]);
  });

  test('video URL validation rejects non-HTTPS and private destinations',
      () async {
    final service = VideoDownloadService();
    await expectLater(service.download('http://example.com/video.mp4'),
        throwsA(isA<FormatException>()));
    await expectLater(service.download('https://127.0.0.1/video.mp4'),
        throwsA(isA<FormatException>()));
  });
}


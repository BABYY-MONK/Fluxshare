import 'package:flutter_test/flutter_test.dart';
import 'package:fluxshare/services/download_manager.dart';

void main() {
  group('ManagedDownload', () {
    test('round trips local task state and validator', () {
      const original = ManagedDownload(
        id: 'task-1',
        url: 'https://example.com/archive.zip',
        name: 'archive.zip',
        destination: r'C:\Users\test\Downloads',
        status: ManagedDownloadStatus.paused,
        totalBytes: 1000,
        segmentOffsets: [250, 500],
        validator: '"file-v1"',
      );

      final restored = ManagedDownload.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.status, ManagedDownloadStatus.paused);
      expect(restored.segmentOffsets, [250, 500]);
      expect(restored.validator, '"file-v1"');
      expect(restored.progress, .75);
    });

    test('sanitizes remote filenames and clamps progress', () {
      final item = ManagedDownload.fromJson({
        'id': 'task-2',
        'url': 'https://example.com/file',
        'name': r'..\private\report?.pdf',
        'destination': r'C:\Downloads',
        'status': 'downloading',
        'totalBytes': 10,
        'segmentOffsets': [12],
      });

      expect(item.name, 'report_.pdf');
      expect(item.progress, 1);
      expect(item.receivedBytes, 12);
    });

    test('unknown persisted statuses recover as paused', () {
      final item = ManagedDownload.fromJson({
        'id': 'task-3',
        'url': 'https://example.com/file',
        'name': 'file.bin',
        'destination': r'C:\Downloads',
        'status': 'future-state',
        'totalBytes': 0,
        'segmentOffsets': [0],
      });

      expect(item.status, ManagedDownloadStatus.paused);
    });
  });

  group('DownloadManager URL safety', () {
    final manager = DownloadManager.instance;

    test('rejects non-HTTPS URLs before opening a connection', () async {
      await expectLater(
        manager.validatePublicHttps('http://example.com/file.zip'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects embedded credentials and local/private destinations',
        () async {
      for (final url in [
        'https://user:password@example.com/file.zip',
        'https://localhost/file.zip',
        'https://10.0.0.8/file.zip',
        'https://192.168.1.1/file.zip',
        'https://192.0.2.8/file.zip',
        'https://[::ffff:127.0.0.1]/file.zip',
      ]) {
        await expectLater(
            manager.validatePublicHttps(url), throwsFormatException);
      }
    });
  });
}

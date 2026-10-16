import 'dart:typed_data';

class DownloadService {
  Future<void> save(Uint8List bytes, String fileName) async {
    throw UnsupportedError('Downloading files is not supported on this platform.');
  }
}

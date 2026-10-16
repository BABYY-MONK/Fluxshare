import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class DownloadService {
  Future<void> save(Uint8List bytes, String fileName) async {
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    // Keep the object URL alive long enough for the browser to begin saving it.
    Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  }
}

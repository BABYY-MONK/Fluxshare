import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class DownloadService {
  Future<void> save(Uint8List bytes, String fileName) async {
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Save converted file',
      fileName: fileName,
    );
    if (destination == null) return;
    await File(destination).writeAsBytes(bytes, flush: true);
  }
}

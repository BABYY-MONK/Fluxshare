// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

/// Bridges browser drag-and-drop and clipboard paste events into Flutter.
class DragDropService {
  final _controller = StreamController<DroppedFile>.broadcast();

  Stream<DroppedFile> get onFileReceived => _controller.stream;

  void initialize() {
    // Prevent browser default file open behavior
    html.document.onDragOver.listen((e) => e.preventDefault());
    html.document.onDrop.listen(_handleDrop);
    html.document.onPaste.listen(_handlePaste);
  }

  void _handleDrop(html.MouseEvent event) {
    event.preventDefault();
    final files = event.dataTransfer.files;
    if (files == null) return;
    for (final file in files) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoad.listen((_) {
        final buffer = reader.result as ByteBuffer;
        _controller.add(DroppedFile(file.name, Uint8List.view(buffer)));
      });
    }
  }

  void _handlePaste(html.ClipboardEvent event) {
    final items = event.clipboardData?.items;
    if (items == null) return;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.kind == 'file') {
        final blob = item.getAsFile();
        if (blob != null) {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(blob);
          reader.onLoad.listen((_) {
            final buffer = reader.result as ByteBuffer;
            final ext = blob.type.contains('/') ? blob.type.split('/').last : 'png';
            final sanitizedExt = ext == 'jpeg' ? 'jpg' : ext;
            final name = blob.name.isNotEmpty && blob.name != 'image.png'
                ? blob.name
                : 'clipboard_${DateTime.now().millisecondsSinceEpoch}.$sanitizedExt';
            _controller.add(DroppedFile(name, Uint8List.view(buffer)));
          });
        }
      }
    }
  }

  void dispose() => _controller.close();
}

class DroppedFile {
  final String name;
  final Uint8List bytes;
  const DroppedFile(this.name, this.bytes);
}

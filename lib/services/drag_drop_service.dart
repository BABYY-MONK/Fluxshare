// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

/// Bridges browser drag-and-drop events into Flutter.
class DragDropService {
  final _controller = StreamController<_DroppedFile>.broadcast();

  Stream<_DroppedFile> get onFileDropped => _controller.stream;

  void initialize() {
    html.document.onDragOver.listen((e) => e.preventDefault());
    html.document.onDrop.listen(_handleDrop);
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
        _controller.add(_DroppedFile(file.name, Uint8List.view(buffer)));
      });
    }
  }

  void dispose() => _controller.close();
}

class _DroppedFile {
  final String name;
  final Uint8List bytes;
  const _DroppedFile(this.name, this.bytes);
}

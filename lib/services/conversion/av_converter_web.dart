import 'dart:typed_data';

import '../../models/file_formats.dart';
import 'server_converter.dart';
import 'conversion_result.dart';

class AvConverter {
  AvConverter({ServerConverter? server}) : _server = server ?? ServerConverter();

  final ServerConverter _server;

  Future<ConversionResult> convert({
    required Uint8List bytes,
    required String originalName,
    required OutputFormat output,
  }) async {
    if (!FormatCatalog.avOutputs.contains(output)) {
      throw StateError('Unsupported audio/video output: ${output.label}');
    }
    return _server.convertMedia(
      bytes: bytes,
      originalName: originalName,
      target: output.extension,
    );
  }
}

import 'dart:typed_data';

import '../../models/file_formats.dart';
import 'conversion_result.dart';

class AvConverter {
  Future<ConversionResult> convert({
    required Uint8List bytes,
    required String originalName,
    required OutputFormat output,
  }) async {
    throw StateError('Audio and video conversions are not available yet.');
  }
}

import 'dart:js_interop';
import 'dart:typed_data';

import '../../models/file_formats.dart';
import 'conversion_result.dart';

@JS('fluxConvertAv')
external JSPromise<JSUint8Array> _fluxConvertAv(
  JSUint8Array bytes,
  JSString inputName,
  JSString outputName,
);

class AvConverter {
  Future<ConversionResult> convert({
    required Uint8List bytes,
    required String originalName,
    required OutputFormat output,
  }) async {
    if (output != OutputFormat.mp3 &&
        output != OutputFormat.wav &&
        output != OutputFormat.gif) {
      throw StateError('Unsupported audio/video output: ${output.label}');
    }
    final stem = originalName.contains('.')
        ? originalName.substring(0, originalName.lastIndexOf('.'))
        : originalName;
    final outName = '$stem.${output.extension}';
    try {
      final result = await _fluxConvertAv(
        bytes.toJS,
        originalName.toJS,
        outName.toJS,
      ).toDart;
      final data = Uint8List.fromList(result.toDart);
      if (data.isEmpty) {
        throw StateError('ffmpeg.wasm returned empty output.');
      }
      return ConversionResult(bytes: data, fileName: outName);
    } catch (error) {
      throw StateError(
        'Audio/video conversion needs ffmpeg.wasm in the browser. $error',
      );
    }
  }
}

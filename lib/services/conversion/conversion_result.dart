import 'dart:typed_data';

class ConversionResult {
  const ConversionResult({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

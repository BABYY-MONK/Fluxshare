import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;

import '../../models/file_formats.dart';
import 'conversion_result.dart';

class ImageConverter {
  Future<ConversionResult> convert({
    required Uint8List bytes,
    required String originalName,
    required OutputFormat output,
    int quality = 85,
    int? maxWidth,
    int? maxHeight,
  }) async {
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image "$originalName".');
    }

    if (maxWidth != null || maxHeight != null) {
      decoded = img.copyResize(
        decoded,
        width: maxWidth,
        height: maxHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    final stem = _stem(originalName);
    switch (output) {
      case OutputFormat.jpg:
        return ConversionResult(
          bytes: Uint8List.fromList(
            img.encodeJpg(decoded, quality: quality.clamp(10, 100).toInt()),
          ),
          fileName: '$stem.jpg',
        );
      case OutputFormat.png:
        return ConversionResult(
          bytes: Uint8List.fromList(img.encodePng(decoded)),
          fileName: '$stem.png',
        );
      case OutputFormat.webp:
        final named = img.encodeNamedImage('out.webp', decoded);
        if (named != null) {
          return ConversionResult(
            bytes: Uint8List.fromList(named),
            fileName: '$stem.webp',
          );
        }
        return ConversionResult(
          bytes: Uint8List.fromList(img.encodePng(decoded)),
          fileName: '$stem.png',
        );
      case OutputFormat.pdf:
        return ConversionResult(
          bytes: await _toPdf(decoded),
          fileName: '$stem.pdf',
        );
      default:
        throw StateError('Unsupported image output: ${output.label}');
    }
  }

  Future<Uint8List> _toPdf(img.Image decoded) async {
    final doc = pw.Document();
    final png = img.encodePng(decoded);
    final memory = pw.MemoryImage(Uint8List.fromList(png));
    doc.addPage(
      pw.Page(
        build: (_) => pw.Center(child: pw.Image(memory, fit: pw.BoxFit.contain)),
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }
}

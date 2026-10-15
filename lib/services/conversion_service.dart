// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';

import '../models/file_item.dart';

/// Handles all client-side file conversion logic (image → image/PDF).
class ConversionService {
  static const _uuid = Uuid();

  // ─── Convert ──────────────────────────────────────────────────────────────

  /// Converts [fileItem] to its [FileItem.targetFormat].
  /// Updates [fileItem.status], [fileItem.convertedBytes], and [fileItem.blobUrl].
  Future<void> convert(FileItem fileItem) async {
    fileItem.status = FileStatus.converting;
    fileItem.errorMessage = null;

    try {
      final Uint8List result = await _dispatch(fileItem);
      fileItem.convertedBytes = result;
      fileItem.status = FileStatus.done;

      // Create blob URL for instant sharing
      final mime = _mimeFor(fileItem.targetFormat.extension);
      final blob = html.Blob([result], mime);
      fileItem.blobUrl = html.Url.createObjectUrlFromBlob(blob);
    } catch (e) {
      fileItem.status = FileStatus.error;
      fileItem.errorMessage = e.toString();
    }
  }

  Future<Uint8List> _dispatch(FileItem item) async {
    final target = item.targetFormat;

    if (item.isImage) {
      if (target == OutputFormat.pdf) {
        return _imageToPdf(item.originalBytes);
      }
      return _convertImage(item.originalBytes, target);
    }

    throw UnsupportedError(
        'Conversion from .${item.originalFormat} → .${target.extension} is not supported in this build.');
  }

  // ─── Image → Image ────────────────────────────────────────────────────────

  Future<Uint8List> _convertImage(Uint8List bytes, OutputFormat target) async {
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Could not decode image — unsupported format.');

    return switch (target) {
      OutputFormat.jpg  => Uint8List.fromList(img.encodeJpg(image, quality: 90)),
      OutputFormat.webp => Uint8List.fromList(img.encodeJpg(image, quality: 90)), // fallback
      OutputFormat.png  => Uint8List.fromList(img.encodePng(image)),
      OutputFormat.gif  => Uint8List.fromList(img.encodeGif(image)),
      _                 => throw UnsupportedError('Target ${target.label} not handled.'),
    };
  }

  // ─── Image → PDF ──────────────────────────────────────────────────────────

  Future<Uint8List> _imageToPdf(Uint8List imageBytes) async {
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: pw.Font.helvetica()),
    );

    final pdfImg = pw.MemoryImage(imageBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context ctx) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(pdfImg, fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  // ─── Download ─────────────────────────────────────────────────────────────

  void download(FileItem item) {
    final bytes = item.convertedBytes ?? item.originalBytes;
    final fileName = item.outputFileName;
    final mime = _mimeFor(item.targetFormat.extension);
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    // Revoke after brief delay
    Future.delayed(const Duration(seconds: 5), () => html.Url.revokeObjectUrl(url));
  }

  // ─── Clipboard / share ────────────────────────────────────────────────────

  Future<void> copyBlobUrlToClipboard(FileItem item) async {
    final url = item.blobUrl;
    if (url == null) return;
    await html.window.navigator.clipboard?.writeText(url);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _mimeFor(String ext) => switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png'           => 'image/png',
    'webp'          => 'image/webp',
    'gif'           => 'image/gif',
    'pdf'           => 'application/pdf',
    _               => 'application/octet-stream',
  };
}

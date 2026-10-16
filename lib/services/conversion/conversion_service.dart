import '../../models/file_formats.dart';
import '../../models/queued_file.dart';
import 'av_converter.dart';
import 'conversion_result.dart';
import 'document_converter.dart';
import 'image_converter.dart';
import 'server_converter.dart';

class ConversionService {
  ConversionService({
    ImageConverter? images,
    DocumentConverter? documents,
    AvConverter? av,
    ServerConverter? server,
  })  : images = images ?? ImageConverter(),
        documents = documents ?? DocumentConverter(),
        av = av ?? AvConverter(),
        server = server ?? ServerConverter();

  final ImageConverter images;
  final DocumentConverter documents;
  final AvConverter av;
  final ServerConverter server;

  Future<ConversionResult> convert(QueuedFile file) {
    switch (file.family) {
      case ConversionFamily.image:
        return images.convert(
          bytes: file.bytes,
          originalName: file.originalName,
          output: file.output,
          quality: file.quality,
          maxWidth: file.maxWidth,
          maxHeight: file.maxHeight,
        );
      case ConversionFamily.document:
        return _convertDocument(file);
      case ConversionFamily.audioVideo:
        return av.convert(
          bytes: file.bytes,
          originalName: file.originalName,
          output: file.output,
        );
      case ConversionFamily.unknown:
        throw StateError('Unsupported file type for "${file.originalName}".');
    }
  }

  Future<ConversionResult> _convertDocument(QueuedFile file) async {
    final ext = FormatCatalog.extensionOf(file.originalName);
    if (ext == 'docx' && file.output == OutputFormat.pdf) {
      final remote = await server.convertDocxToPdf(
        bytes: file.bytes,
        originalName: file.originalName,
      );
      if (remote != null) return remote;
      throw StateError(
        'DOCX to PDF needs a configured LibreOffice conversion endpoint. Other document outputs use extracted text.',
      );
    }
    return documents.convert(
      bytes: file.bytes,
      originalName: file.originalName,
      output: file.output,
    );
  }
}

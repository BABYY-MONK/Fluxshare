import 'package:flutter_test/flutter_test.dart';

import 'package:fluxshare/models/file_formats.dart';

void main() {
  group('FormatCatalog', () {
    test('detects supported formats from filenames and extensions', () {
      expect(FormatCatalog.familyFor('photo.JPEG'), ConversionFamily.image);
      expect(FormatCatalog.familyFor('animated.GIF'), ConversionFamily.image);
      expect(FormatCatalog.familyFor('scan.tiff'), ConversionFamily.image);
      expect(FormatCatalog.familyFor('docx'), ConversionFamily.document);
      expect(FormatCatalog.familyFor('movie.mp4'), ConversionFamily.unknown);
    });

    test('offers only outputs backed by a converter', () {
      expect(FormatCatalog.outputsFor(ConversionFamily.image), contains(OutputFormat.webp));
      expect(FormatCatalog.outputsFor(ConversionFamily.document), contains(OutputFormat.txt));
      expect(FormatCatalog.outputsFor(ConversionFamily.audioVideo), isEmpty);
    });

    test('defaults documents to a loss-aware text conversion', () {
      expect(FormatCatalog.defaultOutput(ConversionFamily.document), OutputFormat.txt);
      expect(FormatCatalog.defaultOutput(ConversionFamily.image), OutputFormat.jpg);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:fluxshare/models/file_formats.dart';
import 'package:fluxshare/models/queued_file.dart';
import 'package:fluxshare/services/conversion/conversion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('converts a PNG image to a valid downloadable JPG', () async {
    final source = img.encodePng(img.Image(width: 2, height: 2));
    final file = QueuedFile(
      id: 'image',
      originalName: 'input.png',
      bytes: Uint8List.fromList(source),
      family: ConversionFamily.image,
      output: OutputFormat.jpg,
      status: FileJobStatus.ready,
    );

    final result = await ConversionService().convert(file);

    expect(result.fileName, 'input.jpg');
    expect(img.decodeJpg(result.bytes), isNotNull);
    expect(result.bytes, isNotEmpty);
  });

  test('converts BMP, GIF, and TIFF images to PNG', () async {
    final sourceImage = img.Image(width: 2, height: 2);
    final service = ConversionService();

    for (final extension in ['bmp', 'gif', 'tiff']) {
      final source = img.encodeNamedImage('input.$extension', sourceImage);
      expect(source, isNotNull, reason: 'test fixture encoder for $extension');
      final file = QueuedFile(
        id: extension,
        originalName: 'input.$extension',
        bytes: Uint8List.fromList(source!),
        family: ConversionFamily.image,
        output: OutputFormat.png,
        status: FileJobStatus.ready,
      );

      final result = await service.convert(file);

      expect(result.fileName, 'input.png');
      expect(img.decodePng(result.bytes), isNotNull, reason: '$extension input');
    }
  });

  test('converts UTF-8 text to a PDF document', () async {
    final file = QueuedFile(
      id: 'text',
      originalName: 'notes.txt',
      bytes: Uint8List.fromList(utf8.encode('FluxShare café — habari')),
      family: ConversionFamily.document,
      output: OutputFormat.pdf,
      status: FileJobStatus.ready,
    );

    final result = await ConversionService().convert(file);

    expect(result.fileName, 'notes.pdf');
    expect(result.bytes.take(4).toList(), [0x25, 0x50, 0x44, 0x46]);
  });

  test('extracts DOCX text and decodes XML entities', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string(
        'word/document.xml',
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body><w:p><w:r><w:t>FluxShare &amp; café</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Second paragraph</w:t></w:r></w:p></w:body></w:document>',
      ));
    final file = QueuedFile(
      id: 'docx',
      originalName: 'notes.docx',
      bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
      family: ConversionFamily.document,
      output: OutputFormat.txt,
      status: FileJobStatus.ready,
    );

    final result = await ConversionService().convert(file);

    expect(utf8.decode(result.bytes), 'FluxShare & café\nSecond paragraph');
  });

  test('converts HTML and Markdown to clean text without markup', () async {
    final converter = ConversionService();
    final html = QueuedFile(
      id: 'html',
      originalName: 'notes.html',
      bytes: Uint8List.fromList(utf8.encode(
        '<html><body><p>Hello &amp; welcome</p><script>not output</script></body></html>',
      )),
      family: ConversionFamily.document,
      output: OutputFormat.txt,
      status: FileJobStatus.ready,
    );
    final markdown = QueuedFile(
      id: 'markdown',
      originalName: 'notes.md',
      bytes: Uint8List.fromList(utf8.encode('# Hello\n\n**Bold** & welcome')),
      family: ConversionFamily.document,
      output: OutputFormat.txt,
      status: FileJobStatus.ready,
    );

    expect(utf8.decode((await converter.convert(html)).bytes), 'Hello & welcome');
    expect(utf8.decode((await converter.convert(markdown)).bytes), 'Hello Bold & welcome');
  });

  test('fails explicitly for unsupported audio/video conversions', () async {
    final file = QueuedFile(
      id: 'av',
      originalName: 'clip.mp4',
      bytes: Uint8List.fromList([0]),
      family: ConversionFamily.audioVideo,
      output: OutputFormat.mp3,
      status: FileJobStatus.ready,
    );

    await expectLater(ConversionService().convert(file), throwsA(isA<StateError>()));
  });
}




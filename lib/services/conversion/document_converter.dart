import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/services.dart' show rootBundle;
import 'package:markdown/markdown.dart' as md;
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart' as xml;

import '../../models/file_formats.dart';
import 'conversion_result.dart';

class DocumentConverter {
  Future<ConversionResult> convert({
    required Uint8List bytes,
    required String originalName,
    required OutputFormat output,
  }) async {
    final ext = FormatCatalog.extensionOf(originalName);
    final raw = utf8.decode(bytes, allowMalformed: true);
    final text = switch (ext) {
      'docx' => _docxToText(bytes),
      'html' || 'htm' => _htmlToText(raw),
      'md' => _markdownToText(raw),
      _ => raw,
    };

    final stem = _stem(originalName);
    switch (output) {
      case OutputFormat.txt:
        return ConversionResult(
          bytes: Uint8List.fromList(utf8.encode(text)),
          fileName: '$stem.txt',
        );
      case OutputFormat.html:
        final html = switch (ext) {
          'md' => _wrapHtml(originalName, md.markdownToHtml(raw)),
          'html' || 'htm' => raw.contains('<html') ? raw : _wrapHtml(originalName, raw),
          _ => _wrapHtml(originalName, '<pre>${_escape(text)}</pre>'),
        };
        return ConversionResult(
          bytes: Uint8List.fromList(utf8.encode(html)),
          fileName: '$stem.html',
        );
      case OutputFormat.pdf:
        return ConversionResult(bytes: await _toPdf(text), fileName: '$stem.pdf');
      default:
        throw StateError('Unsupported document output: ${output.label}');
    }
  }

  String _docxToText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.findFile('word/document.xml');
    if (file == null) {
      throw StateError('Not a valid DOCX file.');
    }
    final document = xml.XmlDocument.parse(
      utf8.decode(file.content as List<int>, allowMalformed: true),
    );
    final paragraphs = document.findAllElements('p', namespaceUri: '*').map(
          (paragraph) => paragraph
              .findAllElements('t', namespaceUri: '*')
              .map((node) => node.innerText)
              .join(),
        );
    final text = paragraphs.where((line) => line.trim().isNotEmpty).join('\n').trim();
    if (text.isEmpty) {
      throw StateError('DOCX contained no readable text.');
    }
    return text;
  }

  Future<Uint8List> _toPdf(String text) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final italic = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Italic.ttf'));
    final boldItalic = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-BoldItalic.ttf'));
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: italic,
        boldItalic: boldItalic,
      ),
    );
    doc.addPage(
      pw.MultiPage(
        maxPages: 200,
        build: (_) => [pw.Paragraph(text: text)],
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  String _htmlToText(String source) {
    final document = html_parser.parse(source);
    document.querySelectorAll('script, style, noscript').forEach((node) => node.remove());
    return document.body?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  }

  String _markdownToText(String source) {
    final rendered = md.markdownToHtml(source);
    return _htmlToText(rendered);
  }

  String _wrapHtml(String title, String body) {
    return '''<!doctype html>
<html>
<head><meta charset="utf-8"><title>${_escape(title)}</title></head>
<body>$body</body>
</html>''';
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }
}

import 'dart:typed_data';

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'conversion/conversion_result.dart';

/// PDF operations backed by FluxShare's optional LibreOffice/PDF service.
/// The server keeps large PDF parsing and compression out of the browser.
class PdfToolsService {
  PdfToolsService({http.Client? client, String? endpoint})
      : _client = client ?? http.Client(),
        endpoint = endpoint ??
            const String.fromEnvironment('LIBREOFFICE_URL', defaultValue: '');

  final http.Client _client;
  final String endpoint;

  Future<ConversionResult> merge(
      List<({String name, Uint8List bytes})> inputs) async {
    if (inputs.length < 2) {
      throw ArgumentError('Choose at least two PDF files to merge.');
    }
    return _post({
      'operation': 'merge',
      'files': [
        for (final file in inputs)
          {'fileName': file.name, 'bytesBase64': base64Encode(file.bytes)}
      ],
    }, 'merged.pdf');
  }

  Future<ConversionResult> compress(Uint8List bytes,
          {String originalName = 'document.pdf'}) =>
      _post({
        'operation': 'compress',
        'fileName': originalName,
        'bytesBase64': base64Encode(bytes),
      }, '${_stem(originalName)}-compressed.pdf');

  Future<ConversionResult> split(
    Uint8List bytes, {
    required String originalName,
    required String pageRanges,
  }) =>
      _post({
        'operation': 'split',
        'fileName': originalName,
        'bytesBase64': base64Encode(bytes),
        'pageRanges': pageRanges,
      }, '${_stem(originalName)}-split.zip');

  Future<ConversionResult> _post(
      Map<String, Object?> body, String fallbackName) async {
    if (endpoint.isEmpty) {
      throw StateError(
          'PDF tools and DOCX to PDF need a configured LibreOffice/PDF service endpoint.');
    }
    final response = await _client
        .post(Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(minutes: 3));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'PDF service returned HTTP ${response.statusCode}: ${response.body}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final encoded = payload['bytesBase64'] as String?;
    if (encoded == null) {
      throw const FormatException(
          'PDF service response is missing bytesBase64.');
    }
    return ConversionResult(
      bytes: base64Decode(encoded),
      fileName: payload['fileName'] as String? ?? fallbackName,
    );
  }

  String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }
}


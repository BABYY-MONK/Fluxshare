import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'conversion_result.dart';

/// Optional LibreOffice Cloud Function / Cloud Run endpoint.
/// Set [endpoint] via `--dart-define=LIBREOFFICE_URL=https://...`.
class ServerConverter {
  ServerConverter({http.Client? client, String? endpoint})
      : _client = client ?? http.Client(),
        endpoint = endpoint ??
            const String.fromEnvironment('LIBREOFFICE_URL', defaultValue: '');

  final http.Client _client;
  final String endpoint;

  bool get isConfigured => endpoint.isNotEmpty;

  Future<ConversionResult?> convertDocxToPdf({
    required Uint8List bytes,
    required String originalName,
  }) async {
    if (!isConfigured) return null;
    try {
      final response = await _client.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fileName': originalName,
          'bytesBase64': base64Encode(bytes),
          'target': 'pdf',
        }),
      );
      if (response.statusCode >= 400) return null;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final encoded = payload['bytesBase64'] as String?;
      final name = payload['fileName'] as String? ??
          originalName.replaceAll(RegExp(r'\.docx$', caseSensitive: false), '.pdf');
      if (encoded == null) return null;
      return ConversionResult(bytes: base64Decode(encoded), fileName: name);
    } catch (_) {
      return null;
    }
  }
}

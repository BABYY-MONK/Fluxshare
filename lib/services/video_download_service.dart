import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'conversion/conversion_result.dart';

class VideoDownloadService {
  VideoDownloadService({http.Client? client})
      : _client = client ?? http.Client();

  static const maxDownloadBytes = 200 * 1024 * 1024;
  static const _videoExtensions = {'mp4', 'webm', 'mov', 'm4v', 'ogv'};
  final http.Client _client;

  Future<ConversionResult> download(String input) async {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        _isPrivateHost(uri.host)) {
      throw const FormatException(
          'Enter a public HTTPS link to a direct video file.');
    }

    try {
      final request = http.Request('GET', uri)
        ..followRedirects = true
        ..maxRedirects = 4;
      final response =
          await _client.send(request).timeout(const Duration(seconds: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
            'The video host returned HTTP ${response.statusCode}.');
      }
      if (response.contentLength != null &&
          response.contentLength! > maxDownloadBytes) {
        throw StateError('Video downloads are limited to 200 MB.');
      }

      final finalUri = response.request?.url ?? uri;
      if (finalUri.scheme != 'https' || _isPrivateHost(finalUri.host)) {
        throw const FormatException(
            'The video host redirected to a blocked address.');
      }
      final contentType =
          response.headers['content-type']?.split(';').first.toLowerCase() ??
              '';
      final extension = _extension(finalUri.path);
      if (!contentType.startsWith('video/') &&
          !_videoExtensions.contains(extension)) {
        throw const FormatException(
            'That link did not return a direct video file.');
      }

      final output = BytesBuilder(copy: false);
      var size = 0;
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 60))) {
        size += chunk.length;
        if (size > maxDownloadBytes) {
          throw StateError('Video downloads are limited to 200 MB.');
        }
        output.add(chunk);
      }
      if (size == 0) throw StateError('The video file was empty.');
      return ConversionResult(
        bytes: Uint8List.fromList(output.takeBytes()),
        fileName:
            'video.${_videoExtensions.contains(extension) ? extension : 'mp4'}',
      );
    } on http.ClientException catch (error) {
      throw StateError(
        'The browser could not read this host. Use a direct video URL from a host that allows cross-origin downloads. $error',
      );
    }
  }

  bool _isPrivateHost(String rawHost) {
    final host = rawHost.toLowerCase().replaceAll('[', '').replaceAll(']', '');
    return host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host == '::1' ||
        host.startsWith('127.') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host) ||
        RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
  }

  String _extension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}


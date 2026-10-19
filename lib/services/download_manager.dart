import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

enum ManagedDownloadStatus { queued, downloading, paused, merging, done, error }

class ManagedDownload {
  const ManagedDownload({
    required this.id,
    required this.url,
    required this.name,
    required this.destination,
    required this.status,
    required this.totalBytes,
    required this.segmentOffsets,
    this.validator,
    this.error,
    this.resultPath,
  });

  final String id;
  final String url;
  final String name;
  final String destination;
  final ManagedDownloadStatus status;
  final int totalBytes;
  final List<int> segmentOffsets;
  final String? validator;
  final String? error;
  final String? resultPath;

  int get receivedBytes => segmentOffsets.fold(0, (sum, value) => sum + value);
  double get progress =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1).toDouble();

  ManagedDownload copyWith({
    ManagedDownloadStatus? status,
    int? totalBytes,
    List<int>? segmentOffsets,
    String? validator,
    String? error,
    String? resultPath,
    bool clearError = false,
  }) =>
      ManagedDownload(
        id: id,
        url: url,
        name: name,
        destination: destination,
        status: status ?? this.status,
        totalBytes: totalBytes ?? this.totalBytes,
        segmentOffsets: segmentOffsets ?? this.segmentOffsets,
        validator: validator ?? this.validator,
        error: clearError ? null : (error ?? this.error),
        resultPath: resultPath ?? this.resultPath,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        'destination': destination,
        'status': status.name,
        'totalBytes': totalBytes,
        'segmentOffsets': segmentOffsets,
        'validator': validator,
        'error': error,
        'resultPath': resultPath,
      };

  factory ManagedDownload.fromJson(Map<String, dynamic> json) =>
      ManagedDownload(
        id: json['id'] as String,
        url: json['url'] as String,
        name: _safeFileName(json['name'] as String? ?? 'download.bin'),
        destination: json['destination'] as String,
        status: ManagedDownloadStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => ManagedDownloadStatus.paused,
        ),
        totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
        segmentOffsets: (json['segmentOffsets'] as List<dynamic>? ?? const [])
            .map((value) => (value as num).toInt())
            .toList(),
        validator: json['validator'] as String?,
        error: json['error'] as String?,
        resultPath: json['resultPath'] as String?,
      );
}

/// Device-local HTTP transfer manager for the Windows desktop build.
/// It never sends URLs, headers, cookies, task metadata, or file data to FluxShare services.
class DownloadManager {
  DownloadManager._();
  static final instance = DownloadManager._();
  static const _uuid = Uuid();
  static const _maxConnections = 4;
  static const _maxActiveTasks = 2;
  static const _maxRedirects = 5;
  static const _journalEvery = Duration(seconds: 3);

  final _downloads = <String, ManagedDownload>{};
  final _clients = <String, Set<HttpClient>>{};
  final _paused = <String>{};
  final _running = <String>{};
  final _resumeAfterPause = <String>{};
  final _persistTails = <String, Future<void>>{};
  final _activeRuns = <String, Future<void>>{};
  final _updates = StreamController<List<ManagedDownload>>.broadcast();
  Future<void>? _initializing;
  Directory? _workspace;

  Stream<List<ManagedDownload>> get updates => _updates.stream;
  List<ManagedDownload> get items => _sorted;
  List<ManagedDownload> get _sorted =>
      _downloads.values.toList()..sort((a, b) => b.id.compareTo(a.id));

  Future<void> initialize() => _initializing ??= _load();

  Future<ManagedDownload> add(String rawUrl, {String? destination}) async {
    await initialize();
    final uri = await validatePublicHttps(rawUrl);
    final targetDir = destination ?? _defaultDownloadsPath();
    await Directory(targetDir).create(recursive: true);
    final client = _newClient('probe');
    final probe = await _request(client, uri, method: 'HEAD');
    var length = int.tryParse(
            probe.headers.value(HttpHeaders.contentLengthHeader) ?? '') ??
        0;
    final name = _filename(probe, uri);
    final etag = probe.headers.value('etag');
    final validator = etag != null && !etag.startsWith('W/')
        ? etag
        : probe.headers.value(HttpHeaders.lastModifiedHeader);
    probe.drain<void>();
    final rangeProbe = await _request(client, uri,
        headers: const {HttpHeaders.rangeHeader: 'bytes=0-0'});
    final contentRange = rangeProbe.headers.value('content-range') ?? '';
    final match = RegExp(r'^bytes 0-0/(\d+)$').firstMatch(contentRange);
    final ranges =
        rangeProbe.statusCode == HttpStatus.partialContent && match != null;
    if (ranges) length = int.tryParse(match.group(1)!) ?? length;
    if (length == 0) {
      length = int.tryParse(
              rangeProbe.headers.value(HttpHeaders.contentLengthHeader) ??
                  '') ??
          0;
    }
    if (ranges) await rangeProbe.drain<void>();
    client.close(force: true);
    final segments = ranges && validator != null && length >= 8 * 1024 * 1024
        ? math.min(
            _maxConnections, math.max(2, (length / (8 * 1024 * 1024)).ceil()))
        : 1;
    final item = ManagedDownload(
      id: _uuid.v4(),
      url: uri.toString(),
      name: name,
      destination: targetDir,
      status: ManagedDownloadStatus.queued,
      totalBytes: length,
      segmentOffsets: List<int>.filled(segments, 0),
      validator: validator,
    );
    _downloads[item.id] = item;
    await _persist(item);
    _emit();
    _pumpQueue();
    return item;
  }

  Future<void> pause(String id) async {
    final item = _downloads[id];
    if (item == null || item.status == ManagedDownloadStatus.done) return;
    _paused.add(id);
    for (final client in _clients.remove(id) ?? <HttpClient>{}) {
      client.close(force: true);
    }
    final updated = item.copyWith(status: ManagedDownloadStatus.paused);
    _downloads[id] = updated;
    await _persist(updated);
    _emit();
  }

  Future<void> resume(String id) async {
    final item = _downloads[id];
    if (item == null || item.status == ManagedDownloadStatus.done) return;
    if (_running.contains(id)) {
      _resumeAfterPause.add(id);
      final queued =
          item.copyWith(status: ManagedDownloadStatus.queued, clearError: true);
      _downloads[id] = queued;
      await _persist(queued);
      _emit();
      return;
    }
    _paused.remove(id);
    final updated =
        item.copyWith(status: ManagedDownloadStatus.queued, clearError: true);
    _downloads[id] = updated;
    await _persist(updated);
    _emit();
    _pumpQueue();
  }

  Future<void> remove(String id, {bool deleteFiles = true}) async {
    _paused.add(id);
    for (final client in _clients.remove(id) ?? <HttpClient>{}) {
      client.close(force: true);
    }
    final activeRun = _activeRuns[id];
    if (activeRun != null) await activeRun;
    final pendingJournal = _persistTails[id];
    if (pendingJournal != null) await pendingJournal.catchError((_) {});
    final item = _downloads.remove(id);
    if (deleteFiles && item != null) {
      try {
        await _taskDirectory(id).delete(recursive: true);
      } on FileSystemException {
        // The task folder may already have been removed after a completed merge.
      }
      if (item.status == ManagedDownloadStatus.done &&
          item.resultPath != null) {
        // Completed downloads belong to the user; removing a queue row never deletes them.
      }
    }
    _emit();
  }

  Future<void> _load() async {
    final root = _rootDirectory();
    await root.create(recursive: true);
    _workspace = root;
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final journal = File('${entity.path}${Platform.pathSeparator}meta.json');
      final backup = File('${journal.path}.bak');
      if (!await journal.exists() && await backup.exists()) {
        await backup.rename(journal.path);
      }
      if (!await journal.exists()) continue;
      try {
        final item = ManagedDownload.fromJson(
            jsonDecode(await journal.readAsString()) as Map<String, dynamic>);
        if (item.id !=
            entity.uri.pathSegments.where((s) => s.isNotEmpty).last) {
          continue;
        }
        final safe = item.status == ManagedDownloadStatus.done
            ? item
            : item.copyWith(status: ManagedDownloadStatus.paused);
        _downloads[safe.id] = safe;
        if (safe.status != item.status) await _persist(safe);
      } catch (_) {
        // An unreadable journal is isolated to its own task folder.
      }
    }
    _emit();
  }

  Future<void> _run(String id) async {
    var item = _downloads[id];
    if (item == null ||
        _paused.contains(id) ||
        item.status == ManagedDownloadStatus.done) {
      await _releaseRun(id);
      return;
    }
    item = item.copyWith(
        status: ManagedDownloadStatus.downloading, clearError: true);
    _downloads[id] = item;
    await _persist(item);
    _emit();
    try {
      final uri = await validatePublicHttps(item.url);
      if (item.segmentOffsets.length == 1 && item.totalBytes == 0) {
        await _downloadUnknownLength(id, uri);
      } else if (item.segmentOffsets.length == 1) {
        await _downloadSingle(id, uri);
      } else {
        await Future.wait(List.generate(item.segmentOffsets.length,
            (index) => _downloadSegment(id, uri, index)));
      }
      if (_paused.contains(id)) return;
      item = _downloads[id]!;
      final merging = item.copyWith(status: ManagedDownloadStatus.merging);
      _downloads[id] = merging;
      await _persist(merging);
      _emit();
      final path = await _merge(merging);
      final complete = merging.copyWith(
          status: ManagedDownloadStatus.done, resultPath: path);
      _downloads[id] = complete;
      await _persist(complete);
    } catch (error) {
      if (_paused.contains(id)) return;
      final current = _downloads[id];
      if (current == null) return;
      final failed = current.copyWith(
        status: ManagedDownloadStatus.error,
        error: _friendlyError(error),
      );
      _downloads[id] = failed;
      await _persist(failed);
    } finally {
      await _releaseRun(id);
    }
  }

  Future<void> _releaseRun(String id) async {
    _clients.remove(id)?.forEach((client) => client.close(force: true));
    _running.remove(id);
    if (_resumeAfterPause.remove(id)) {
      _paused.remove(id);
      final current = _downloads[id];
      if (current != null) {
        final queued = current.copyWith(
            status: ManagedDownloadStatus.queued, clearError: true);
        _downloads[id] = queued;
        await _persist(queued);
      }
    }
    _emit();
    _pumpQueue();
  }

  void _pumpQueue() {
    while (_running.length < _maxActiveTasks) {
      final queued = _sorted.where((item) =>
          item.status == ManagedDownloadStatus.queued &&
          !_paused.contains(item.id) &&
          !_running.contains(item.id));
      if (queued.isEmpty) return;
      final item = queued.first;
      _running.add(item.id);
      final active = _run(item.id);
      _activeRuns[item.id] = active;
      unawaited(active.whenComplete(() => _activeRuns.remove(item.id)));
    }
  }

  Future<void> _downloadSegment(String id, Uri uri, int index) async {
    var item = _downloads[id]!;
    final total = item.totalBytes;
    if (total <= 0) return _downloadUnknownLength(id, uri);
    final count = item.segmentOffsets.length;
    final start = total * index ~/ count;
    final endExclusive = total * (index + 1) ~/ count;
    var offset = item.segmentOffsets[index];
    if (offset >= endExclusive - start) return;
    final segmentFile = File(
        '${_taskDirectory(id).path}${Platform.pathSeparator}shard-${index.toString().padLeft(4, '0')}.part');
    await segmentFile.parent.create(recursive: true);
    final client = _newClient(id);
    try {
      final response = await _request(
        client,
        uri,
        headers: {
          HttpHeaders.rangeHeader:
              'bytes=${start + offset}-${endExclusive - 1}',
          if (item.validator != null)
            HttpHeaders.ifRangeHeader: item.validator!,
        },
      );
      if (response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        throw StateError(
            'The server stopped honoring byte ranges. Resume this task as a single stream or retry from the beginning.');
      }
      final contentRange = response.headers.value('content-range') ?? '';
      final match =
          RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(contentRange);
      if (match == null ||
          int.tryParse(match.group(1)!) != start + offset ||
          int.tryParse(match.group(2)!) != endExclusive - 1 ||
          int.tryParse(match.group(3)!) != total) {
        await response.drain<void>();
        throw StateError(
            'The server returned an unexpected byte range; the partial file was kept for safe recovery.');
      }
      final file = await segmentFile.open(
          mode: offset == 0 ? FileMode.write : FileMode.append);
      if (offset > 0) await file.truncate(offset);
      var written = 0;
      var lastJournal = DateTime.now();
      try {
        await for (final chunk
            in response.timeout(const Duration(seconds: 60))) {
          if (_paused.contains(id)) break;
          if (offset + chunk.length > endExclusive - start) {
            throw StateError(
                'The server sent more data than the requested segment.');
          }
          await file.writeFrom(chunk);
          written += chunk.length;
          offset += chunk.length;
          item = _downloads[id]!;
          final offsets = [...item.segmentOffsets]..[index] = offset;
          final updated = item.copyWith(segmentOffsets: offsets);
          _downloads[id] = updated;
          if (DateTime.now().difference(lastJournal) >= _journalEvery) {
            await file.flush();
            await _persist(updated);
            lastJournal = DateTime.now();
            _emit();
          }
        }
        await file.flush();
      } finally {
        await file.close();
      }
      if (!_paused.contains(id) && offset != endExclusive - start) {
        throw StateError(
            'The connection ended before the segment completed. Resume to continue.');
      }
      if (!_paused.contains(id) &&
          written == 0 &&
          offset < endExclusive - start) {
        throw StateError('The server returned no data for this segment.');
      }
    } finally {
      client.close(force: true);
      _clients[id]?.remove(client);
    }
  }

  Future<void> _downloadSingle(String id, Uri uri) async {
    var item = _downloads[id]!;
    var offset = item.segmentOffsets.single;
    final path =
        '${_taskDirectory(id).path}${Platform.pathSeparator}shard-0000.part';
    final client = _newClient(id);
    try {
      if (offset > 0 && item.validator == null) {
        offset = 0;
        item = item.copyWith(segmentOffsets: [0]);
        _downloads[id] = item;
        await _persist(item);
      }
      var response = await _request(
        client,
        uri,
        headers: offset == 0
            ? const {}
            : {
                HttpHeaders.rangeHeader: 'bytes=$offset-',
                if (item.validator != null)
                  HttpHeaders.ifRangeHeader: item.validator!,
              },
      );
      if (offset > 0 && response.statusCode != HttpStatus.partialContent) {
        // A server which ignores Range cannot safely resume; discard the partial bytes and restart.
        await response.drain<void>();
        offset = 0;
        item = item.copyWith(segmentOffsets: [0]);
        _downloads[id] = item;
        await _persist(item);
        response = await _request(client, uri);
        final newLength = response.contentLength;
        item = _downloads[id]!;
        if (newLength > 0) {
          item = item.copyWith(totalBytes: newLength);
          _downloads[id] = item;
          await _persist(item);
        }
      }
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        await response.drain<void>();
        throw StateError('The server returned HTTP ${response.statusCode}.');
      }
      if (response.statusCode == HttpStatus.partialContent) {
        final contentRange = response.headers.value('content-range') ?? '';
        if (!contentRange.startsWith('bytes $offset-')) {
          await response.drain<void>();
          throw StateError('The server returned an unexpected byte range.');
        }
      }
      final file = await File(path)
          .open(mode: offset == 0 ? FileMode.write : FileMode.append);
      if (offset > 0) await file.truncate(offset);
      var received = offset;
      var lastJournal = DateTime.now();
      try {
        await for (final chunk
            in response.timeout(const Duration(seconds: 60))) {
          if (_paused.contains(id)) break;
          if (item.totalBytes > 0 &&
              received + chunk.length > item.totalBytes) {
            throw StateError(
                'The server sent more data than the announced file size.');
          }
          await file.writeFrom(chunk);
          received += chunk.length;
          item = _downloads[id]!;
          final updated = item.copyWith(segmentOffsets: [received]);
          _downloads[id] = updated;
          if (DateTime.now().difference(lastJournal) >= _journalEvery) {
            await file.flush();
            await _persist(updated);
            _emit();
            lastJournal = DateTime.now();
          }
        }
        await file.flush();
      } finally {
        await file.close();
      }
      if (!_paused.contains(id) && received != item.totalBytes) {
        throw StateError(
            'The connection ended before the file completed. Resume to continue.');
      }
    } finally {
      client.close(force: true);
      _clients[id]?.remove(client);
    }
  }

  Future<void> _downloadUnknownLength(String id, Uri uri) async {
    final client = _newClient(id);
    try {
      final response = await _request(client, uri);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw StateError('The server returned HTTP ${response.statusCode}.');
      }
      final path =
          '${_taskDirectory(id).path}${Platform.pathSeparator}shard-0000.part';
      final file = await File(path).open(mode: FileMode.write);
      var received = 0;
      var lastJournal = DateTime.now();
      try {
        await for (final chunk
            in response.timeout(const Duration(seconds: 60))) {
          if (_paused.contains(id)) break;
          await file.writeFrom(chunk);
          received += chunk.length;
          if (DateTime.now().difference(lastJournal) >= _journalEvery) {
            await file.flush();
            final current = _downloads[id]!;
            final updated = current.copyWith(segmentOffsets: [received]);
            _downloads[id] = updated;
            await _persist(updated);
            _emit();
            lastJournal = DateTime.now();
          }
        }
        await file.flush();
      } finally {
        await file.close();
      }
    } finally {
      client.close(force: true);
      _clients[id]?.remove(client);
    }
  }

  Future<String> _merge(ManagedDownload item) async {
    final partial = File(
        '${item.destination}${Platform.pathSeparator}.${item.id}.fluxpart');
    final output = await partial.open(mode: FileMode.write);
    try {
      for (var i = 0; i < item.segmentOffsets.length; i++) {
        final shard = File(
            '${_taskDirectory(item.id).path}${Platform.pathSeparator}shard-${i.toString().padLeft(4, '0')}.part');
        if (!await shard.exists()) {
          throw StateError(
              'A download segment is missing. Resume the task to rebuild the file.');
        }
        final expected = item.totalBytes > 0
            ? item.totalBytes * (i + 1) ~/ item.segmentOffsets.length -
                item.totalBytes * i ~/ item.segmentOffsets.length
            : item.segmentOffsets[i];
        if (item.segmentOffsets[i] != expected ||
            await shard.length() != expected) {
          throw StateError(
              'A download segment failed its size check. Resume the task to repair it.');
        }
        await for (final chunk in shard.openRead()) {
          await output.writeFrom(chunk);
        }
      }
      await output.flush();
    } finally {
      await output.close();
    }
    var result =
        '${item.destination}${Platform.pathSeparator}${_safeFileName(item.name)}';
    var suffix = 1;
    while (await File(result).exists()) {
      final dot = item.name.lastIndexOf('.');
      final stem = dot > 0 ? item.name.substring(0, dot) : item.name;
      final extension = dot > 0 ? item.name.substring(dot) : '';
      result =
          '${item.destination}${Platform.pathSeparator}$stem ($suffix)$extension';
      suffix++;
    }
    await partial.rename(result);
    await _taskDirectory(item.id).delete(recursive: true);
    return result;
  }

  Future<HttpClientResponse> _request(HttpClient client, Uri initial,
      {String method = 'GET', Map<String, String> headers = const {}}) async {
    var uri = initial;
    for (var redirects = 0; redirects <= _maxRedirects; redirects++) {
      await validatePublicHttps(uri.toString());
      final request = await client.openUrl(method, uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'FluxShare/1.0');
      headers.forEach(request.headers.set);
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if (![
        HttpStatus.movedPermanently,
        HttpStatus.found,
        HttpStatus.seeOther,
        HttpStatus.temporaryRedirect,
        HttpStatus.permanentRedirect
      ].contains(response.statusCode)) {
        return response;
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null || redirects == _maxRedirects) {
        throw StateError('The download URL redirected too many times.');
      }
      uri = uri.resolve(location);
      if (response.statusCode == HttpStatus.seeOther && method != 'HEAD') {
        method = 'GET';
      }
    }
    throw StateError('Could not follow the download redirect.');
  }

  Future<Uri> validatePublicHttps(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException(
          'Use a public HTTPS URL. Local addresses and embedded credentials are not allowed.');
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local')) {
      throw const FormatException(
          'Local network URLs are blocked for download safety.');
    }
    final addresses = InternetAddress.tryParse(host) == null
        ? await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 10))
        : [InternetAddress(host)];
    if (addresses.isEmpty || addresses.any(_isPrivateAddress)) {
      throw const FormatException(
          'The URL resolves to a local or reserved network address.');
    }
    return uri;
  }

  bool _isPrivateAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return true;
    }
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return _isPrivateIpv4(bytes);
    }
    if (bytes.length == 16 &&
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 255 &&
        bytes[11] == 255) {
      return _isPrivateIpv4(bytes.sublist(12));
    }
    return bytes.every((byte) => byte == 0) || (bytes[0] & 0xfe) == 0xfc;
  }

  bool _isPrivateIpv4(List<int> bytes) =>
      bytes.every((byte) => byte == 0) ||
      bytes[0] == 0 ||
      bytes[0] == 10 ||
      bytes[0] == 127 ||
      bytes[0] >= 224 ||
      (bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127) ||
      (bytes[0] == 169 && bytes[1] == 254) ||
      (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
      (bytes[0] == 192 && bytes[1] == 168) ||
      (bytes[0] == 192 && bytes[1] == 0 && bytes[2] == 0) ||
      (bytes[0] == 192 && bytes[1] == 0 && bytes[2] == 2) ||
      (bytes[0] == 198 && (bytes[1] == 18 || bytes[1] == 19)) ||
      (bytes[0] == 198 && bytes[1] == 51 && bytes[2] == 100) ||
      (bytes[0] == 203 && bytes[1] == 0 && bytes[2] == 113);

  String _filename(HttpClientResponse response, Uri uri) {
    final disposition = response.headers.value('content-disposition');
    final encoded = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
        .firstMatch(disposition ?? '')
        ?.group(1);
    final plain = RegExp(r'filename\s*=\s*"?([^";]+)', caseSensitive: false)
        .firstMatch(disposition ?? '')
        ?.group(1);
    final candidate = encoded != null
        ? Uri.decodeComponent(encoded)
        : plain ??
            (uri.pathSegments.isEmpty ? 'download.bin' : uri.pathSegments.last);
    return _safeFileName(candidate);
  }

  Directory _rootDirectory() {
    final local = Platform.environment['LOCALAPPDATA'];
    final root =
        local == null || local.isEmpty ? Directory.systemTemp.path : local;
    return Directory(
        '$root${Platform.pathSeparator}FluxShare${Platform.pathSeparator}downloads');
  }

  String _defaultDownloadsPath() {
    final user = Platform.environment['USERPROFILE'];
    return '${user ?? Directory.current.path}${Platform.pathSeparator}Downloads';
  }

  Directory _taskDirectory(String id) => Directory(
      '${(_workspace ?? _rootDirectory()).path}${Platform.pathSeparator}$id');

  HttpClient _newClient(String id) {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      if (proxyHost != null || proxyPort != null) {
        throw const SocketException('Proxy connections are not supported.');
      }
      final addresses = await InternetAddress.lookup(uri.host)
          .timeout(const Duration(seconds: 10));
      if (addresses.isEmpty || addresses.any(_isPrivateAddress)) {
        throw const SocketException(
            'The download host resolves to a local or reserved address.');
      }
      return Socket.startConnect(addresses.first, uri.port);
    };
    _clients.putIfAbsent(id, () => <HttpClient>{}).add(client);
    return client;
  }

  Future<void> _persist(ManagedDownload item) {
    final previous = _persistTails[item.id] ?? Future<void>.value();
    final next = previous.catchError((_) {}).then((_) => _writeJournal(item));
    _persistTails[item.id] = next;
    return next.whenComplete(() {
      if (identical(_persistTails[item.id], next)) {
        _persistTails.remove(item.id);
      }
    });
  }

  Future<void> _writeJournal(ManagedDownload item) async {
    final directory = _taskDirectory(item.id);
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}meta.json');
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temporary.writeAsString(jsonEncode(item.toJson()), flush: true);
    if (await backup.exists()) await backup.delete();
    if (await file.exists()) await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } on FileSystemException {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }

  void _emit() => _updates.add(_sorted);

  String _friendlyError(Object error) {
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('SocketException: ', 'Network error: ');
    if (message.contains('HandshakeException')) {
      return 'Secure connection failed. Check the site certificate and network.';
    }
    if (message.contains('Failed host lookup')) {
      return 'Could not find that host. Check the URL and your connection.';
    }
    return message;
  }
}

String _safeFileName(String value) {
  final normalized = value
      .replaceAll('\\', '/')
      .split('/')
      .last
      .replaceAll(RegExp(r'[<>:"|?*\x00-\x1f]'), '_')
      .trim();
  if (normalized.isEmpty || normalized == '.' || normalized == '..') {
    return 'download.bin';
  }
  return normalized.length > 180
      ? normalized.substring(normalized.length - 180)
      : normalized;
}

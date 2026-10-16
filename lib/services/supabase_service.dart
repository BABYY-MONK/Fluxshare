import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SharedFile {
  const SharedFile({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.storagePath,
    required this.expiresAt,
  });

  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String storagePath;
  final DateTime expiresAt;
}

/// Supabase access used by FluxShare. The publishable key is intentionally a
/// public build-time value; database and Storage RLS policies protect writes.
class SupabaseService {
  SupabaseService(this.client);

  static const _publicAppUrl = String.fromEnvironment('FLUXSHARE_PUBLIC_URL');

  static const bucket = 'shared-files';
  static const maxFileBytes = 50 * 1024 * 1024;
  static const freeDailyLimit = 3;
  static const shareLifetime = Duration(hours: 24);
  static const _uuid = Uuid();

  final SupabaseClient client;

  String? get userId => client.auth.currentUser?.id;

  Future<void> ensureAnonymousSession() async {
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  }

  Future<int> loadDailyUsage() async {
    await ensureAnonymousSession();
    final user = userId;
    if (user == null) return 0;
    final rows = await client
        .from('daily_usage')
        .select('slot')
        .eq('user_id', user)
        .eq('usage_date', _utcDateKey(DateTime.now().toUtc()));
    return rows.length;
  }

  /// Atomically records one conversion; returns false when the free limit is hit.
  Future<bool> consumeConversion() async {
    await ensureAnonymousSession();
    final user = userId;
    if (user == null) throw StateError('Could not establish a guest session.');
    final date = _utcDateKey(DateTime.now().toUtc());
    for (var attempt = 0; attempt < freeDailyLimit; attempt++) {
      final rows = await client
          .from('daily_usage')
          .select('slot')
          .eq('user_id', user)
          .eq('usage_date', date);
      final used = rows.map((row) => (row['slot'] as num).toInt()).toSet();
      final slot = List<int>.generate(freeDailyLimit, (index) => index + 1)
          .firstWhere((candidate) => !used.contains(candidate), orElse: () => 0);
      if (slot == 0) return false;
      try {
        await client.from('daily_usage').insert({
          'user_id': user,
          'usage_date': date,
          'slot': slot,
        });
        return true;
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
      }
    }
    return false;
  }

  Future<String> createShareLink({
    required Uint8List bytes,
    required String fileName,
    required String extension,
  }) async {
    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw StateError('Shared files must be between 1 byte and 50 MB.');
    }
    await ensureAnonymousSession();
    final ownerId = userId;
    if (ownerId == null) throw StateError('Could not establish a guest session.');

    final shareId = _uuid.v4();
    final path = '$ownerId/$shareId';
    final expiresAt = DateTime.now().toUtc().add(shareLifetime);
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _mimeType(extension)),
        );
    try {
      await client.from('share_links').insert({
        'id': shareId,
        'owner_id': ownerId,
        'storage_path': path,
        'file_name': fileName,
        'content_type': _mimeType(extension),
        'size_bytes': bytes.length,
        'expires_at': expiresAt.toIso8601String(),
      });
    } catch (_) {
      await client.storage.from(bucket).remove([path]);
      rethrow;
    }

    if (!kIsWeb && _publicAppUrl.isEmpty) {
      throw StateError('Set FLUXSHARE_PUBLIC_URL before sharing from the desktop app.');
    }
    final baseUri = kIsWeb ? Uri.base : Uri.parse(_publicAppUrl);
    final params = Map<String, String>.from(baseUri.queryParameters)
      ..remove('share')
      ..['share'] = shareId;
    return baseUri.replace(queryParameters: params).toString();
  }

  Future<SharedFile?> findActiveShare(String id) async {
    final row = await client
        .from('share_links')
        .select('id,file_name,content_type,size_bytes,storage_path,expires_at')
        .eq('id', id)
        .isFilter('revoked_at', null)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .maybeSingle();
    if (row == null) return null;
    return SharedFile(
      id: row['id'] as String,
      fileName: row['file_name'] as String,
      contentType: row['content_type'] as String,
      sizeBytes: (row['size_bytes'] as num).toInt(),
      storagePath: row['storage_path'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
    );
  }

  Future<Uint8List> downloadSharedFile(SharedFile file) async {
    final bytes = await client.storage.from(bucket).download(file.storagePath);
    return Uint8List.fromList(bytes);
  }

  String _utcDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _mimeType(String ext) => switch (ext.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        'txt' => 'text/plain',
        'html' => 'text/html',
        'mp3' => 'audio/mpeg',
        'wav' => 'audio/wav',
        'gif' => 'image/gif',
        _ => 'application/octet-stream',
      };
}

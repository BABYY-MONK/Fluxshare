import 'package:flutter/material.dart';

import '../services/download_service.dart';
import '../services/supabase_service.dart';

class SharedFileScreen extends StatefulWidget {
  const SharedFileScreen({super.key, required this.supabase, required this.shareId});

  final SupabaseService? supabase;
  final String shareId;

  @override
  State<SharedFileScreen> createState() => _SharedFileScreenState();
}

class _SharedFileScreenState extends State<SharedFileScreen> {
  final _downloads = DownloadService();
  SharedFile? _file;
  String? _error;
  bool _loading = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.supabase == null) {
      setState(() {
        _loading = false;
        _error = 'This share link is not available because cloud sharing is not configured.';
      });
      return;
    }
    try {
      final file = await widget.supabase!.findActiveShare(widget.shareId);
      if (!mounted) return;
      setState(() {
        _file = file;
        _loading = false;
        if (file == null) _error = 'This link has expired or was removed.';
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load this share link.'; });
    }
  }

  Future<void> _download() async {
    final file = _file;
    if (file == null || widget.supabase == null) return;
    setState(() => _downloading = true);
    try {
      final bytes = await widget.supabase!.downloadSharedFile(file);
      await _downloads.save(bytes, file.fileName);
    } catch (_) {
      if (mounted) setState(() => _error = 'Download failed. The link may have expired.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('FluxShare')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _loading
                    ? const CircularProgressIndicator()
                    : _error != null
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.link_off, size: 48),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                          ])
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.description_outlined, size: 52),
                            const SizedBox(height: 16),
                            Text(_file!.fileName, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text('${(_file!.sizeBytes / 1024).toStringAsFixed(1)} KB · expires ${_file!.expiresAt}'),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _downloading ? null : _download,
                              icon: const Icon(Icons.download),
                              label: Text(_downloading ? 'Preparing…' : 'Download file'),
                            ),
                          ]),
              ),
            ),
          ),
        ),
      );
}

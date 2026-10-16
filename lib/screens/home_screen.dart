import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/file_formats.dart';
import '../models/queued_file.dart';
import '../services/conversion/conversion_service.dart';
import '../services/download_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.supabase});

  final SupabaseService? supabase;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _converter = ConversionService();
  final _downloads = DownloadService();
  final _uuid = const Uuid();
  final List<QueuedFile> _files = [];
  int _usedToday = 0;
  bool _cloudReady = false;
  String? _cloudMessage;

  @override
  void initState() {
    super.initState();
    _loadCloudState();
  }

  Future<void> _loadCloudState() async {
    final service = widget.supabase;
    if (service == null) return;
    try {
      final used = await service.loadDailyUsage();
      if (mounted) setState(() { _usedToday = used; _cloudReady = true; });
    } catch (error) {
      if (mounted) setState(() => _cloudMessage = 'Cloud sharing is unavailable: $error');
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ...FormatCatalog.imageInputs,
        ...FormatCatalog.documentInputs,
      ],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    for (final picked in result.files) {
      final bytes = picked.bytes;
      if (bytes != null) _addFile(picked.name, bytes);
    }
  }

  void _addFile(String name, Uint8List bytes) {
    if (bytes.length > SupabaseService.maxFileBytes) {
      _toast('Files must be 50 MB or smaller.');
      return;
    }
    final family = FormatCatalog.familyFor(name);
    final formats = FormatCatalog.outputsFor(family);
    if (family == ConversionFamily.unknown || formats.isEmpty) {
      _toast('That file type is not supported yet.');
      return;
    }
    setState(() => _files.insert(0, QueuedFile(
          id: _uuid.v4(),
          originalName: name,
          bytes: bytes,
          family: family,
          output: FormatCatalog.defaultOutput(family),
          status: FileJobStatus.ready,
        )));
  }

  Future<void> _convert(QueuedFile file) async {
    final index = _files.indexWhere((f) => f.id == file.id);
    if (index < 0 || file.status == FileJobStatus.converting) return;
    if (!_cloudReady && _usedToday >= SupabaseService.freeDailyLimit) {
      _toast('You have used the 3 local demo conversions for this session.');
      return;
    }

    setState(() => _files[index] = file.copyWith(
          status: FileJobStatus.converting,
          clearError: true,
          clearConverted: true,
          clearShare: true,
        ));
    try {
      final result = await _converter.convert(file);
      if (_cloudReady && widget.supabase != null) {
        final allowed = await widget.supabase!.consumeConversion();
        if (!allowed) throw StateError('You have used today’s 3 free conversions. Try again tomorrow.');
      }
      if (!mounted) return;
      final current = _files.indexWhere((f) => f.id == file.id);
      if (current >= 0) {
        setState(() {
          _usedToday++;
          _files[current] = _files[current].copyWith(
            status: FileJobStatus.ready,
            convertedBytes: result.bytes,
            convertedName: result.fileName,
          );
        });
      }
    } catch (error) {
      if (!mounted) return;
      final current = _files.indexWhere((f) => f.id == file.id);
      if (current >= 0) {
        setState(() => _files[current] = _files[current].copyWith(
              status: FileJobStatus.error,
              errorMessage: error.toString().replaceFirst('Bad state: ', ''),
            ));
      }
    }
  }

  Future<void> _share(QueuedFile file) async {
    final service = widget.supabase;
    final bytes = file.convertedBytes;
    final name = file.convertedName;
    if (service == null || bytes == null || name == null) {
      _toast('Convert this file and configure Supabase before sharing.');
      return;
    }
    if (!_cloudReady) {
      _toast(_cloudMessage ?? 'Connecting to Supabase…');
      return;
    }
    try {
      final link = await service.createShareLink(
        bytes: bytes,
        fileName: name,
        extension: FormatCatalog.extensionOf(name),
      );
      final index = _files.indexWhere((f) => f.id == file.id);
      if (index >= 0) setState(() => _files[index] = _files[index].copyWith(shareUrl: link));
      if (mounted) await _showShareDialog(name, link);
    } catch (error) {
      _toast('Could not create a share link: $error');
    }
  }

  Future<void> _showShareDialog(String fileName, String url) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Link ready to share'),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(fileName, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              QrImageView(data: url, size: 220),
              const SizedBox(height: 10),
              const Text('Anyone with this link can download it for 24 hours.', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              SelectableText(url, textAlign: TextAlign.center),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) Navigator.pop(context);
                _toast('Link copied.');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy link'),
            ),
          ],
        ),
      );

  Future<void> _download(QueuedFile file) async {
    final bytes = file.convertedBytes;
    final name = file.convertedName;
    if (bytes == null || name == null) return;
    try {
      await _downloads.save(bytes, name);
    } catch (error) {
      _toast('Could not save the converted file: $error');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final available = SupabaseService.freeDailyLimit - _usedToday;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.bolt_rounded, color: AppColors.electric),
          SizedBox(width: 8),
          Text('FluxShare'),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Chip(
              avatar: const Icon(Icons.bolt, size: 18),
              label: Text(_cloudReady ? '$available free today' : 'Local mode'),
            )),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Convert files. Share them securely.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Conversions run in your browser. Shared files are encrypted at rest and their links expire after 24 hours.', style: Theme.of(context).textTheme.bodyLarge),
              if (widget.supabase == null) ...[
                const SizedBox(height: 18),
                const _InfoBanner(text: 'Local conversion is ready. Add the Supabase URL and publishable key to enable cloud sharing and synced daily limits.'),
              ] else if (_cloudMessage != null) ...[
                const SizedBox(height: 18),
                _InfoBanner(text: _cloudMessage!),
              ],
              const SizedBox(height: 24),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _pickFiles,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                    child: Column(children: [
                      const Icon(Icons.cloud_upload_outlined, size: 44, color: AppColors.electric),
                      const SizedBox(height: 12),
                      Text('Choose files to convert', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      const Text('JPG, PNG, WebP, TXT, Markdown, HTML and DOCX · up to 50 MB per file'),
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: _pickFiles, icon: const Icon(Icons.add), label: const Text('Select files')),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              for (final file in _files) _fileCard(file),
              if (_files.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _files.clear()),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear queue'),
                  ),
                ),
              const SizedBox(height: 20),
              const Text('Files stay on your device unless you choose to create a share link. Shared files are removed from access after 24 hours.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileCard(QueuedFile file) {
    final outputs = FormatCatalog.outputsFor(file.family);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.insert_drive_file_outlined, color: AppColors.electric),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(file.originalName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(_size(file.size), style: const TextStyle(color: AppColors.muted)),
            ])),
            IconButton(tooltip: 'Remove', onPressed: () => setState(() => _files.removeWhere((f) => f.id == file.id)), icon: const Icon(Icons.close)),
          ]),
          if (file.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(file.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            DropdownButton<OutputFormat>(
              value: file.output,
              items: outputs.map((format) => DropdownMenuItem(value: format, child: Text(format.label))).toList(),
              onChanged: file.status == FileJobStatus.converting ? null : (value) {
                if (value == null) return;
                final index = _files.indexWhere((f) => f.id == file.id);
                setState(() => _files[index] = file.copyWith(output: value, status: FileJobStatus.ready, clearConverted: true, clearError: true, clearShare: true));
              },
            ),
            FilledButton.icon(
              onPressed: file.status == FileJobStatus.converting ? null : () => _convert(file),
              icon: file.status == FileJobStatus.converting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.transform),
              label: Text(file.status == FileJobStatus.converting ? 'Converting…' : file.convertedBytes == null ? 'Convert' : 'Convert again'),
            ),
            if (file.convertedBytes != null) OutlinedButton.icon(onPressed: () => _download(file), icon: const Icon(Icons.download), label: Text('Download ${file.convertedName}')),
            if (file.convertedBytes != null) OutlinedButton.icon(onPressed: () => _share(file), icon: const Icon(Icons.share), label: const Text('Share')),
          ]),
        ]),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.electric.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
        child: Text(text),
      );
}

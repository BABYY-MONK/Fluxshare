import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/file_formats.dart';
import '../models/queued_file.dart';
import '../services/conversion/conversion_service.dart';
import '../services/download_service.dart';
import '../services/download_manager_platform.dart';
import '../services/file_tools_service.dart';
import '../services/pdf_tools_service.dart';
import '../services/supabase_service.dart';
import '../services/video_download_service.dart';
import 'download_manager_screen_platform.dart';
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
  final _pdfTools = PdfToolsService();
  final _fileTools = FileToolsService();
  final _videoTools = VideoDownloadService();
  final _videoUrl = TextEditingController();
  final List<QueuedFile> _files = [];
  int _usedToday = 0;
  bool _cloudReady = false;
  String? _cloudMessage;
  bool _toolBusy = false;

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
      if (mounted) {
        setState(() {
          _usedToday = used;
          _cloudReady = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _cloudMessage = 'Cloud sharing is unavailable: $error');
      }
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ...FormatCatalog.imageInputs,
        ...FormatCatalog.documentInputs,
        ...FormatCatalog.avInputs,
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
    final formats = FormatCatalog.outputsFor(family, inputName: name);
    if (family == ConversionFamily.unknown || formats.isEmpty) {
      _toast('That file type is not supported yet.');
      return;
    }
    setState(() => _files.insert(
        0,
        QueuedFile(
          id: _uuid.v4(),
          originalName: name,
          bytes: bytes,
          family: family,
          output: FormatCatalog.defaultOutput(family, inputName: name),
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
        if (!allowed) {
          throw StateError(
              'You have used today’s 3 free conversions. Try again tomorrow.');
        }
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
      if (index >= 0) {
        setState(() => _files[index] = _files[index].copyWith(shareUrl: link));
      }
      if (mounted) await _showShareDialog(name, link);
    } catch (error) {
      _toast('Could not create a share link: $error');
    }
  }

  Future<void> _showShareDialog(String fileName, String url) =>
      showDialog<void>(
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
              const Text('Anyone with this link can download it for 24 hours.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              SelectableText(url, textAlign: TextAlign.center),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
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

  Future<List<PlatformFile>> _pickPdfs({required bool multiple}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: multiple,
      withData: true,
    );
    return result?.files ?? const [];
  }

  Future<void> _mergePdfs() async {
    final files = await _pickPdfs(multiple: true);
    if (files.length < 2) {
      if (files.isNotEmpty) _toast('Choose at least two PDFs to merge.');
      return;
    }
    await _runTool(() async {
      final merged = await _pdfTools.merge([
        for (final file in files)
          if (file.bytes != null) (name: file.name, bytes: file.bytes!),
      ]);
      await _downloads.save(merged.bytes, merged.fileName);
    }, 'Merged PDF downloaded.');
  }

  Future<void> _singlePdfTool({required bool compress}) async {
    final files = await _pickPdfs(multiple: false);
    if (files.isEmpty || files.first.bytes == null) return;
    final file = files.first;
    if (compress) {
      await _runTool(() async {
        final result =
            await _pdfTools.compress(file.bytes!, originalName: file.name);
        await _downloads.save(result.bytes, result.fileName);
      }, 'Compressed PDF downloaded.');
      return;
    }

    if (!mounted) return;
    final rangeController = TextEditingController();
    final ranges = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extract PDF pages'),
        content: TextField(
          controller: rangeController,
          autofocus: true,
          decoration:
              const InputDecoration(labelText: 'Pages', hintText: '1-3, 5'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, rangeController.text),
              child: const Text('Extract')),
        ],
      ),
    );
    rangeController.dispose();
    if (ranges == null || ranges.trim().isEmpty) return;
    await _runTool(() async {
      final result = await _pdfTools.split(file.bytes!,
          originalName: file.name, pageRanges: ranges);
      await _downloads.save(result.bytes, result.fileName);
    }, 'Extracted pages downloaded as a ZIP.');
  }

  Future<void> _rotatePdf() async {
    final files = await _pickPdfs(multiple: false);
    if (files.isEmpty || files.first.bytes == null) return;
    final file = files.first;
    await _runTool(() async {
      final result = await _pdfTools.rotate(file.bytes!, originalName: file.name);
      await _downloads.save(result.bytes, result.fileName);
    }, 'Rotated PDF downloaded.');
  }

  Future<void> _ocrPdf() async {
    final files = await _pickPdfs(multiple: false);
    if (files.isEmpty || files.first.bytes == null) return;
    final file = files.first;
    await _runTool(() async {
      final result = await _pdfTools.ocr(file.bytes!, originalName: file.name);
      await _downloads.save(result.bytes, result.fileName);
    }, 'Recognized text downloaded.');
  }

  Future<void> _zipFiles() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.any, allowMultiple: true, withData: true);
    if (result == null || result.files.isEmpty) return;
    await _runTool(() async {
      final picked = <({String name, Uint8List bytes})>[];
      var total = 0;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) throw StateError('Could not read ${file.name}.');
        total += bytes.length;
        if (total > 200 * 1024 * 1024) {
          throw StateError('ZIP input is limited to 200 MB total.');
        }
        picked.add((name: file.name, bytes: bytes));
      }
      await _downloads.save(
          _fileTools.createZip(picked), 'fluxshare-files.zip');
    }, 'ZIP archive downloaded.');
  }

  Future<void> _downloadVideo() async {
    await _runTool(() async {
      final result = await _videoTools.download(_videoUrl.text);
      await _downloads.save(result.bytes, result.fileName);
    }, 'Video downloaded.');
  }

  Future<void> _runTool(Future<void> Function() action, String success) async {
    setState(() => _toolBusy = true);
    try {
      await action();
      if (mounted) _toast(success);
    } catch (error) {
      if (mounted) _toast(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _toolBusy = false);
    }
  }

  @override
  void dispose() {
    _videoUrl.dispose();
    super.dispose();
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
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.electric,
              boxShadow: [
                BoxShadow(color: AppColors.electric, blurRadius: 16),
              ],
            ),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(Icons.bolt_rounded, size: 20, color: AppColors.canvas),
            ),
          ),
          SizedBox(width: 11),
          Text('FluxShare'),
        ]),
        actions: [
          if (supportsWindowsDownloadManager)
            IconButton(
              tooltip: 'Download manager',
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const DownloadManagerScreen(),
              )),
              icon: const Icon(Icons.download_for_offline_outlined),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
                child: Chip(
              avatar: const Icon(Icons.bolt, size: 18),
              label: Text(_cloudReady ? '$available free today' : 'Local mode'),
            )),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned(
            top: -190,
            right: -115,
            child: _AmbientGlow(color: AppColors.violet, size: 420),
          ),
          const Positioned(
            top: 280,
            left: -240,
            child: _AmbientGlow(color: AppColors.electricDark, size: 440),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF182B45), Color(0xFF101827), Color(0xFF1B1934)],
                    ),
                    border: Border.all(color: AppColors.outline),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.electric.withValues(alpha: .08),
                        blurRadius: 38,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final title = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.electric.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.electric.withValues(alpha: .24)),
                          ),
                          child: const Text(
                            'YOUR CREATIVE FILE WORKSPACE',
                            style: TextStyle(
                              color: AppColors.electric,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Convert files. Share them securely.',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.15,
                                height: 1.08,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'One focused workspace for documents, media, and quick file tools.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.muted,
                                height: 1.5,
                              ),
                        ),
                      ],
                    );
                    if (compact) return title;
                    return Row(children: [
                      Expanded(child: title),
                      const SizedBox(width: 24),
                      const _FluxOrb(),
                    ]);
                  }),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _statusPill(Icons.lock_outline, 'Private by default'),
                _statusPill(Icons.bolt_outlined, 'Fast local tools'),
                _statusPill(Icons.timer_outlined, '24-hour sharing'),
              ]),
              if (widget.supabase == null) ...[
                const SizedBox(height: 18),
                const _InfoBanner(
                    text:
                        'Local conversion is ready. Add the Supabase URL and publishable key to enable cloud sharing and synced daily limits.'),
              ] else if (_cloudMessage != null) ...[
                const SizedBox(height: 18),
                _InfoBanner(text: _cloudMessage!),
              ],
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [AppColors.surfaceRaised, AppColors.card.withValues(alpha: .92)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppColors.electric.withValues(alpha: .25)),
                  boxShadow: [
                    BoxShadow(color: AppColors.electric.withValues(alpha: .06), blurRadius: 28),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _pickFiles,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
                    child: Column(children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.electric.withValues(alpha: .10),
                          border: Border.all(color: AppColors.electric.withValues(alpha: .35)),
                          boxShadow: [BoxShadow(color: AppColors.electric.withValues(alpha: .12), blurRadius: 22)],
                        ),
                        child: const Icon(Icons.upload_file_rounded,
                            size: 32, color: AppColors.electric),
                      ),
                      const SizedBox(height: 16),
                      Text('Choose files to convert',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'Images · documents · audio · video',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Select files · up to 50 MB')),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Column(
                    key: ValueKey(_files.map((f) => f.id).join(',')),
                    children: [
                      for (final file in _files) _fileCard(file),
                    ]),
              ),
              const SizedBox(height: 18),
              Text('More tools',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _toolButton('Merge PDFs', Icons.merge_type, _mergePdfs),
                _toolButton('Compress PDF', Icons.compress,
                    () => _singlePdfTool(compress: true)),
                _toolButton('Extract pages', Icons.content_cut,
                    () => _singlePdfTool(compress: false)),
                _toolButton('Rotate PDF', Icons.rotate_90_degrees_cw,
                    _rotatePdf),
                _toolButton('OCR to text', Icons.document_scanner_outlined,
                    _ocrPdf),
                _toolButton('Create ZIP', Icons.folder_zip_outlined, _zipFiles),
              ]),
              const SizedBox(height: 12),
              Card(
                  child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Download a direct video file',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text(
                          'HTTPS MP4, WebM, MOV and M4V links up to 200 MB. The source host must allow browser access.'),
                      const SizedBox(height: 10),
                      LayoutBuilder(builder: (context, constraints) {
                        final input = TextField(
                            controller: _videoUrl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                                hintText: 'https://example.com/video.mp4',
                                border: OutlineInputBorder()));
                        final button = FilledButton.icon(
                            onPressed: _toolBusy ? null : _downloadVideo,
                            icon: _toolBusy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.download),
                            label: Text(_toolBusy ? 'Working…' : 'Download'));
                        if (constraints.maxWidth < 560) {
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                input,
                                const SizedBox(height: 10),
                                button
                              ]);
                        }
                        return Row(children: [
                          Expanded(child: input),
                          const SizedBox(width: 10),
                          button,
                        ]);
                      }),
                    ]),
              )),
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
              Text(
                'Files stay on your device unless you choose to share. Shared links expire after 24 hours.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.mint),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _fileCard(QueuedFile file) {
    final outputs = FormatCatalog.outputsFor(
      file.family,
      inputName: file.originalName,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, 10 * (1 - value)), child: child)),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.insert_drive_file_outlined,
                  color: AppColors.electric),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(file.originalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(_size(file.size),
                        style: const TextStyle(color: AppColors.muted)),
                  ])),
              IconButton(
                  tooltip: 'Remove',
                  onPressed: () => setState(
                      () => _files.removeWhere((f) => f.id == file.id)),
                  icon: const Icon(Icons.close)),
            ]),
            if (file.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(file.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<OutputFormat>(
                    value: file.output,
                    items: outputs
                        .map((format) => DropdownMenuItem(
                            value: format, child: Text(format.label)))
                        .toList(),
                    onChanged: file.status == FileJobStatus.converting
                        ? null
                        : (value) {
                            if (value == null) return;
                            final index =
                                _files.indexWhere((f) => f.id == file.id);
                            setState(() => _files[index] = file.copyWith(
                                output: value,
                                status: FileJobStatus.ready,
                                clearConverted: true,
                                clearError: true,
                                clearShare: true));
                          },
                  ),
                  FilledButton.icon(
                    onPressed: file.status == FileJobStatus.converting
                        ? null
                        : () => _convert(file),
                    icon: file.status == FileJobStatus.converting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.transform),
                    label: Text(file.status == FileJobStatus.converting
                        ? 'Converting…'
                        : file.convertedBytes == null
                            ? 'Convert'
                            : 'Convert again'),
                  ),
                  if (file.convertedBytes != null)
                    OutlinedButton.icon(
                        onPressed: () => _download(file),
                        icon: const Icon(Icons.download),
                        label: Text('Download ${file.convertedName}')),
                  if (file.convertedBytes != null)
                    OutlinedButton.icon(
                        onPressed: () => _share(file),
                        icon: const Icon(Icons.share),
                        label: const Text('Share')),
                ]),
          ]),
        ),
      ),
    );
  }

  Widget _toolButton(String label, IconData icon, VoidCallback onPressed) =>
      FilledButton.tonalIcon(
          onPressed: _toolBusy ? null : onPressed,
          icon: Icon(icon),
          label: Text(label));
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.electric.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text),
      );
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: .13), color.withValues(alpha: 0)],
            ),
          ),
        ),
      );
}

class _FluxOrb extends StatelessWidget {
  const _FluxOrb();

  @override
  Widget build(BuildContext context) => Container(
        width: 152,
        height: 152,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.electric, AppColors.violet],
          ),
          boxShadow: [
            BoxShadow(color: AppColors.electric.withValues(alpha: .28), blurRadius: 48),
            BoxShadow(color: AppColors.violet.withValues(alpha: .22), blurRadius: 68),
          ],
        ),
        child: Center(
          child: Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.navy,
              border: Border.all(color: Colors.white.withValues(alpha: .24), width: 2),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 52, color: AppColors.electric),
          ),
        ),
      );
}

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../models/file_item.dart';
import '../services/conversion_service.dart';
import '../services/drag_drop_service.dart';
import '../theme/app_theme.dart';
import '../widgets/drop_zone.dart';
import '../widgets/file_card.dart';
import '../widgets/navbar.dart';
import '../widgets/stats_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _conversionService = ConversionService();
  final _dragDropService   = DragDropService();
  final _uuid              = const Uuid();

  final List<FileItem> _files = [];
  bool _isDraggingOver = false;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _dragDropService.initialize();
    _dragDropService.onFileDropped.listen((dropped) {
      _addFile(dropped.name, dropped.bytes);
    });
  }

  @override
  void dispose() {
    _dragDropService.dispose();
    super.dispose();
  }

  // ─── File handling ────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.bytes != null) _addFile(f.name, f.bytes!);
    }
  }

  void _addFile(String name, Uint8List bytes) {
    final ext = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    final supported = kSupportedConversions.containsKey(ext);
    if (!supported) {
      _showSnack('⚠️  .${ext.toUpperCase()} is not supported yet.', isError: true);
      return;
    }

    final formats = kSupportedConversions[ext]!;
    final item = FileItem(
      id: _uuid.v4(),
      originalName: name,
      originalBytes: bytes,
      originalFormat: ext,
      targetFormat: formats.first,
    );
    setState(() => _files.insert(0, item));
  }

  void _removeFile(FileItem item) => setState(() => _files.remove(item));

  void _clearAll() => setState(() => _files.clear());

  // ─── Conversion ───────────────────────────────────────────────────────────

  Future<void> _convertFile(FileItem item) async {
    setState(() {});           // trigger rebuild to show spinner
    await _conversionService.convert(item);
    setState(() {});           // show done state
  }

  Future<void> _convertAll() async {
    final pending = _files.where((f) => f.status == FileStatus.ready).toList();
    for (final f in pending) {
      await _conversionService.convert(f);
      setState(() {});
    }
  }

  // ─── Download / share ─────────────────────────────────────────────────────

  void _download(FileItem item) => _conversionService.download(item);

  Future<void> _copyLink(FileItem item) async {
    await _conversionService.copyBlobUrlToClipboard(item);
    _showSnack('🔗  Link copied — valid while this tab stays open.');
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.bgElevated,
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  int get _doneCount    => _files.where((f) => f.status == FileStatus.done).length;
  int get _pendingCount => _files.where((f) => f.status == FileStatus.ready).length;
  int get _errorCount   => _files.where((f) => f.status == FileStatus.error).length;

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: Column(
        children: [
          // ── Navbar ──────────────────────────────────────────────────────
          const FluxNavbar(),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 64 : 20,
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero text ─────────────────────────────────────────
                  _HeroHeader(),
                  const SizedBox(height: 32),

                  // ── Drop zone ─────────────────────────────────────────
                  DropZoneWidget(
                    onPickFiles: _pickFiles,
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.08, end: 0),
                  const SizedBox(height: 24),

                  // ── Stats + action bar ────────────────────────────────
                  if (_files.isNotEmpty) ...[
                    StatsBar(
                      total: _files.length,
                      done: _doneCount,
                      pending: _pendingCount,
                      errors: _errorCount,
                      onConvertAll: _pendingCount > 0 ? _convertAll : null,
                      onClearAll: _clearAll,
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 20),
                  ],

                  // ── File grid ─────────────────────────────────────────
                  if (_files.isEmpty)
                    _EmptyState()
                  else
                    _buildFileGrid(isWide),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileGrid(bool isWide) {
    final crossAxisCount = isWide ? 2 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isWide ? 2.6 : 2.2,
      ),
      itemCount: _files.length,
      itemBuilder: (context, i) {
        final file = _files[i];
        return FileCard(
          key: ValueKey(file.id),
          file: file,
          onFormatChanged: (fmt) => setState(() => file.targetFormat = fmt),
          onConvert: () => _convertFile(file),
          onDownload: () => _download(file),
          onCopyLink: () => _copyLink(file),
          onRemove: () => _removeFile(file),
        ).animate(delay: Duration(milliseconds: i * 60)).fadeIn().slideY(begin: 0.06, end: 0);
      },
    );
  }
}

// ── Hero header widget ──────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.accentGradient.createShader(bounds),
          child: Text(
            'Convert & Share\nInstantly',
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -1.5,
              color: Colors.white,
            ),
          ),
        ).animate().fadeIn(duration: 700.ms).slideY(begin: -0.05, end: 0),
        const SizedBox(height: 14),
        Text(
          'Drop your files below. Convert between JPG, PNG, WEBP, PDF and more — entirely in your browser, no upload to any server.',
          style: GoogleFonts.inter(
            fontSize: 17,
            color: AppTheme.textSecondary,
            height: 1.6,
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 600.ms),
      ],
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.accentGradient,
              ),
              child: const Icon(Icons.folder_open_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'No files yet',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Drag & drop or click "Choose Files" to get started.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95)),
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../models/file_item.dart';
import '../services/conversion_service.dart';
import '../services/drag_drop_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/drop_zone.dart';
import '../widgets/file_card.dart';
import '../widgets/navbar.dart';
import '../widgets/share_dialog.dart';
import '../widgets/stats_bar.dart';
import '../widgets/upgrade_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _conversionService = ConversionService();
  final _dragDropService   = DragDropService();
  final _firebaseService   = FirebaseService();
  final _uuid              = const Uuid();

  final List<FileItem> _files = [];

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _dragDropService.initialize();
    _dragDropService.onFileReceived.listen((received) {
      _addFile(received.name, received.bytes);
      _showSnack('📥 Added "${received.name}"');
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
    if (!_firebaseService.currentQuota.canConvert) {
      _showQuotaExceededDialog();
      return;
    }

    setState(() {}); // Trigger rebuild to show spinner
    await _conversionService.convert(item);
    if (item.status == FileStatus.done) {
      _firebaseService.recordConversion();
    }
    setState(() {}); // Show done state
  }

  Future<void> _convertAll() async {
    final pending = _files.where((f) => f.status == FileStatus.ready).toList();
    for (final f in pending) {
      if (!_firebaseService.currentQuota.canConvert) {
        _showQuotaExceededDialog();
        break;
      }
      await _conversionService.convert(f);
      if (f.status == FileStatus.done) {
        _firebaseService.recordConversion();
      }
      setState(() {});
    }
  }

  // ─── Cloud Sync / Upload ──────────────────────────────────────────────────

  Future<void> _uploadToCloud(FileItem item) async {
    if (item.isUploadingToCloud || item.isUploadedToCloud) return;

    setState(() {
      item.isUploadingToCloud = true;
      item.uploadProgress = 0.05;
    });

    try {
      final url = await _firebaseService.uploadAndShareFile(
        fileItem: item,
        onProgress: (p) {
          if (mounted) setState(() => item.uploadProgress = p);
        },
      );

      if (mounted) {
        setState(() {
          item.isUploadingToCloud = false;
          item.isUploadedToCloud = true;
        });

        _showSnack('☁️ Uploaded to Cloud! Ready for cross-device share.');
        ShareDialog.show(context, file: item);
      }
    } catch (e) {
      if (mounted) {
        setState(() => item.isUploadingToCloud = false);
        _showSnack('Upload failed: $e', isError: true);
      }
    }
  }

  Future<void> _uploadAllToCloud() async {
    final eligible = _files
        .where((f) => f.status == FileStatus.done && !f.isUploadedToCloud)
        .toList();

    for (final f in eligible) {
      await _uploadToCloud(f);
    }
  }

  // ─── Download / share ─────────────────────────────────────────────────────

  void _download(FileItem item) => _conversionService.download(item);

  Future<void> _copyLink(FileItem item) async {
    await _conversionService.copyBlobUrlToClipboard(item);
    _showSnack('🔗 Link copied to clipboard!');
  }

  // ─── UI helpers ───────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.error : AppTheme.bgElevated,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showQuotaExceededDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: AppTheme.warning),
            const SizedBox(width: 8),
            Text('Daily Limit Reached',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ],
        ),
        content: Text(
          'You have reached your 3 free conversions for today. Upgrade to FluxShare Pro for unlimited batch conversions and permanent cloud links.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close',
                style: GoogleFonts.inter(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              UpgradeModal.show(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
            ),
            child: Text('Upgrade to Pro',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ─── Stats ────────────────────────────────────────────────────────────────

  int get _doneCount        => _files.where((f) => f.status == FileStatus.done).length;
  int get _pendingCount     => _files.where((f) => f.status == FileStatus.ready).length;
  int get _errorCount       => _files.where((f) => f.status == FileStatus.error).length;
  int get _cloudSyncedCount => _files.where((f) => f.isUploadedToCloud).length;
  bool get _canUploadAll    => _files.any((f) => f.status == FileStatus.done && !f.isUploadedToCloud);

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
                      cloudSynced: _cloudSyncedCount,
                      onConvertAll: _pendingCount > 0 ? _convertAll : null,
                      onUploadAllToCloud: _canUploadAll ? _uploadAllToCloud : null,
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
        childAspectRatio: isWide ? 2.5 : 2.1,
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
          onUploadToCloud: () => _uploadToCloud(file),
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
          'Drop files, pick them, or paste directly with Ctrl+V. Convert between JPG, PNG, WEBP, and PDF client-side — then generate instant QR codes and cloud sharing links.',
          style: GoogleFonts.inter(
            fontSize: 16,
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.accentGradient,
              ),
              child: const Icon(Icons.folder_open_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'No files queued',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Drag & drop, click "Choose Files", or press Ctrl+V to paste a screenshot.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95)),
      ),
    );
  }
}

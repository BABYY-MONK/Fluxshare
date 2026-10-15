import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/file_item.dart';
import '../theme/app_theme.dart';

/// A single file card shown in the workspace grid.
class FileCard extends StatefulWidget {
  final FileItem file;
  final ValueChanged<OutputFormat> onFormatChanged;
  final VoidCallback onConvert;
  final VoidCallback onDownload;
  final VoidCallback onCopyLink;
  final VoidCallback onRemove;

  const FileCard({
    super.key,
    required this.file,
    required this.onFormatChanged,
    required this.onConvert,
    required this.onDownload,
    required this.onCopyLink,
    required this.onRemove,
  });

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;

  FileItem get f => widget.file;

  // ─── Status helpers ───────────────────────────────────────────────────────

  Color get _statusColor => switch (f.status) {
        FileStatus.ready      => AppTheme.accent,
        FileStatus.converting => AppTheme.warning,
        FileStatus.done       => AppTheme.success,
        FileStatus.error      => AppTheme.error,
      };

  String get _statusLabel => switch (f.status) {
        FileStatus.ready      => 'Ready',
        FileStatus.converting => 'Converting…',
        FileStatus.done       => 'Converted',
        FileStatus.error      => 'Error',
      };

  IconData get _fileIcon {
    if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'tiff', 'tif']
        .contains(f.originalFormat)) {
      return Icons.image_rounded;
    }
    if (f.originalFormat == 'pdf') return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? AppTheme.accent.withOpacity(0.4) : AppTheme.borderColor,
            width: 1,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildMiddle(),
              const Spacer(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        // File icon badge
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_fileIcon, color: _statusColor, size: 20),
        ),
        const SizedBox(width: 12),

        // File name + extension badge
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.originalName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                f.formattedSize,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),

        // Status pill
        _StatusPill(label: _statusLabel, color: _statusColor),
        const SizedBox(width: 8),

        // Remove
        _IconBtn(
          icon: Icons.close_rounded,
          onTap: widget.onRemove,
          color: AppTheme.textSecondary,
          hoverColor: AppTheme.error,
        ),
      ],
    );
  }

  // ─── Middle — format selector / progress ──────────────────────────────────

  Widget _buildMiddle() {
    if (f.status == FileStatus.converting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Processing…',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: AppTheme.bgElevated,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.warning),
              minHeight: 4,
            ),
          ),
        ],
      );
    }

    if (f.status == FileStatus.error) {
      return Text(
        f.errorMessage ?? 'Conversion failed.',
        style:
            GoogleFonts.inter(fontSize: 12, color: AppTheme.error),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (f.status == FileStatus.done) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '.${f.originalFormat.toUpperCase()} → .${f.targetFormat.extension.toUpperCase()}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.success,
              ),
            ),
          ),
        ],
      );
    }

    // Ready — show format picker
    return Row(
      children: [
        Text(
          'Convert to:',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 10),
        _FormatDropdown(
          value: f.targetFormat,
          options: f.availableFormats,
          onChanged: widget.onFormatChanged,
        ),
      ],
    );
  }

  // ─── Footer — action buttons ───────────────────────────────────────────────

  Widget _buildFooter() {
    if (f.status == FileStatus.ready || f.status == FileStatus.error) {
      return Row(
        children: [
          _GradientButton(
            label: f.status == FileStatus.error ? 'Retry' : 'Convert',
            icon: Icons.auto_fix_high_rounded,
            onTap: widget.onConvert,
          ),
        ],
      );
    }

    if (f.status == FileStatus.done) {
      return Row(
        children: [
          _GradientButton(
            label: 'Download',
            icon: Icons.download_rounded,
            onTap: widget.onDownload,
          ),
          const SizedBox(width: 8),
          _OutlineButton(
            label: 'Copy Link',
            icon: Icons.link_rounded,
            onTap: widget.onCopyLink,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color hoverColor;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.hoverColor,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered ? widget.hoverColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: _hovered ? widget.hoverColor : widget.color,
          ),
        ),
      ),
    );
  }
}

class _FormatDropdown extends StatelessWidget {
  final OutputFormat value;
  final List<OutputFormat> options;
  final ValueChanged<OutputFormat> onChanged;

  const _FormatDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OutputFormat>(
          value: options.contains(value) ? value : options.first,
          dropdownColor: AppTheme.bgElevated,
          style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary),
          isDense: true,
          items: options
              .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f.label),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(9),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.bgElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: _hovered ? AppTheme.accent : AppTheme.borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 15,
                  color: _hovered ? AppTheme.accentGlow : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _hovered ? AppTheme.accentGlow : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

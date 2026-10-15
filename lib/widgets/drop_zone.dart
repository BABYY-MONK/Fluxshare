import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Large animated drag-and-drop + file picker zone.
class DropZoneWidget extends StatefulWidget {
  final VoidCallback onPickFiles;
  const DropZoneWidget({super.key, required this.onPickFiles});

  @override
  State<DropZoneWidget> createState() => _DropZoneWidgetState();
}

class _DropZoneWidgetState extends State<DropZoneWidget>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPickFiles,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: _hovering
                ? AppTheme.accent.withOpacity(0.07)
                : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: DottedBorder(
            borderType: BorderType.RRect,
            radius: const Radius.circular(20),
            color: _hovering ? AppTheme.accentGlow : AppTheme.borderColor,
            strokeWidth: 2,
            dashPattern: const [8, 6],
            child: SizedBox.expand(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated icon
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _hovering
                            ? AppTheme.accentGradient
                            : const LinearGradient(
                                colors: [AppTheme.bgElevated, AppTheme.bgCard]),
                        boxShadow: _hovering
                            ? [
                                BoxShadow(
                                  color: AppTheme.accent.withOpacity(
                                      0.3 + 0.2 * _pulseCtrl.value),
                                  blurRadius: 24 + 8 * _pulseCtrl.value,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        Icons.cloud_upload_rounded,
                        color: _hovering
                            ? Colors.white
                            : AppTheme.textSecondary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _hovering
                        ? 'Release to upload'
                        : 'Drag & drop files here',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _hovering
                          ? AppTheme.accentGlow
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'or',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _PickButton(onTap: widget.onPickFiles),
                  const SizedBox(height: 16),
                  Text(
                    'Supported: JPG · PNG · WEBP · GIF · BMP · TIFF',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PickButton({required this.onTap});

  @override
  State<_PickButton> createState() => _PickButtonState();
}

class _PickButtonState extends State<_PickButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            gradient: _hovered ? AppTheme.accentGradient : null,
            color: _hovered ? null : AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? Colors.transparent : AppTheme.borderColor,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            'Choose Files',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

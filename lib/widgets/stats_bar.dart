import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Stats bar shown above the file grid showing counts + batch action buttons.
class StatsBar extends StatelessWidget {
  final int total, done, pending, errors, cloudSynced;
  final VoidCallback? onConvertAll;
  final VoidCallback? onUploadAllToCloud;
  final VoidCallback onClearAll;

  const StatsBar({
    super.key,
    required this.total,
    required this.done,
    required this.pending,
    required this.errors,
    this.cloudSynced = 0,
    required this.onConvertAll,
    this.onUploadAllToCloud,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Stat pills
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Stat(label: 'Total', value: total, color: AppTheme.textSecondary),
              const SizedBox(width: 16),
              _Stat(label: 'Ready', value: pending, color: AppTheme.accent),
              const SizedBox(width: 16),
              _Stat(label: 'Done', value: done, color: AppTheme.success),
              if (cloudSynced > 0) ...[
                const SizedBox(width: 16),
                _Stat(label: 'Cloud', value: cloudSynced, color: AppTheme.accentGlow),
              ],
              if (errors > 0) ...[
                const SizedBox(width: 16),
                _Stat(label: 'Errors', value: errors, color: AppTheme.error),
              ],
            ],
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Convert all
              if (onConvertAll != null)
                _ActionButton(
                  label: 'Convert All',
                  icon: Icons.auto_fix_high_rounded,
                  onTap: onConvertAll!,
                  gradient: AppTheme.accentGradient,
                ),
              if (onUploadAllToCloud != null) ...[
                const SizedBox(width: 10),
                _ActionButton(
                  label: 'Sync All to Cloud',
                  icon: Icons.cloud_upload_rounded,
                  onTap: onUploadAllToCloud!,
                  color: AppTheme.bgElevated,
                  textColor: AppTheme.accentGlow,
                ),
              ],
              const SizedBox(width: 10),

              // Clear all
              _ActionButton(
                label: 'Clear All',
                icon: Icons.delete_sweep_rounded,
                onTap: onClearAll,
                color: AppTheme.bgElevated,
                textColor: AppTheme.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: GoogleFonts.inter(
              fontSize: 19, fontWeight: FontWeight.w700, color: color),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient? gradient;
  final Color? color;
  final Color textColor;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.gradient,
    this.color,
    this.textColor = Colors.white,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.gradient == null ? widget.color : null,
            borderRadius: BorderRadius.circular(10),
            border: widget.gradient == null
                ? Border.all(color: AppTheme.borderColor)
                : null,
            boxShadow: _hovered && widget.gradient != null
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: widget.textColor),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

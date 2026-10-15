import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/file_item.dart';
import '../theme/app_theme.dart';

/// Stats bar shown above the file grid showing counts + action buttons.
class StatsBar extends StatelessWidget {
  final int total, done, pending, errors;
  final VoidCallback? onConvertAll;
  final VoidCallback onClearAll;

  const StatsBar({
    super.key,
    required this.total,
    required this.done,
    required this.pending,
    required this.errors,
    required this.onConvertAll,
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
      child: Row(
        children: [
          // Stat pills
          _Stat(label: 'Total', value: total, color: AppTheme.textSecondary),
          const SizedBox(width: 16),
          _Stat(label: 'Done', value: done, color: AppTheme.success),
          const SizedBox(width: 16),
          _Stat(label: 'Ready', value: pending, color: AppTheme.accent),
          if (errors > 0) ...[
            const SizedBox(width: 16),
            _Stat(label: 'Errors', value: errors, color: AppTheme.error),
          ],

          const Spacer(),

          // Convert all
          if (onConvertAll != null)
            _ActionButton(
              label: 'Convert All',
              icon: Icons.auto_fix_high_rounded,
              onTap: onConvertAll!,
              gradient: AppTheme.accentGradient,
            ),
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
              fontSize: 20, fontWeight: FontWeight.w700, color: color),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    fontSize: 13,
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

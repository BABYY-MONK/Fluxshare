import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

/// Modal dialog highlighting the Free vs Pro plan comparison.
class UpgradeModal extends StatelessWidget {
  const UpgradeModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => const UpgradeModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebase = FirebaseService();
    final isPro = firebase.currentUser?.isPro ?? false;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header Icon ──
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),

              Text(
                'Supercharge FluxShare',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock heavy file conversions, permanent links, and unlimited daily usage.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // ── Comparison Table / Cards ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Free Plan
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Free Tier',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 4),
                          Text('\$0 / forever',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          const _FeatureRow(text: '3 conversions / day', checked: true),
                          const _FeatureRow(text: '50MB max file size', checked: true),
                          const _FeatureRow(text: '24-hour link expiry', checked: true),
                          const _FeatureRow(text: 'Permanent cloud storage', checked: false),
                          const _FeatureRow(text: 'Batch cloud upload', checked: false),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Pro Plan
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF131D31)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.accent.withOpacity(0.5), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Pro Plan',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentGlow)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('POPULAR',
                                    style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('\$5 / month',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          const _FeatureRow(text: 'Unlimited conversions', checked: true),
                          const _FeatureRow(text: '2GB max file size', checked: true),
                          const _FeatureRow(text: 'Permanent cloud links', checked: true),
                          const _FeatureRow(text: 'Batch cloud sync', checked: true),
                          const _FeatureRow(text: 'Priority processing', checked: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Action Buttons ──
              if (isPro)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'You are currently enjoying FluxShare Pro!',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Keep Free',
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            firebase.activateProPlan();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🎉 FluxShare Pro features activated!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Activate Pro Plan',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final bool checked;
  const _FeatureRow({required this.text, required this.checked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 14,
            color: checked ? AppTheme.accentGlow : AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: checked ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'upgrade_modal.dart';

class FluxNavbar extends StatelessWidget {
  const FluxNavbar({super.key});

  @override
  Widget build(BuildContext context) {
    final firebase = FirebaseService();

    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppTheme.bgDeep.withOpacity(0.95),
        border: const Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.accentGradient.createShader(bounds),
                child: Text(
                  'FluxShare',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms),

          const Spacer(),

          // Quota / Tier Badge (Dynamic from FirebaseService)
          StreamBuilder<UserQuota>(
            stream: firebase.quotaStream,
            initialData: firebase.currentQuota,
            builder: (context, snapshot) {
              final quota = snapshot.data ?? firebase.currentQuota;
              if (quota.isPro) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'PRO ACTIVE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Tooltip(
                message: 'Daily free conversions remaining',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        quota.remaining > 0
                            ? Icons.hourglass_top_rounded
                            : Icons.lock_clock_rounded,
                        size: 13,
                        color: quota.remaining > 0
                            ? AppTheme.accentGlow
                            : AppTheme.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${quota.remaining}/${quota.limit} free left',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: quota.remaining > 0
                              ? AppTheme.textPrimary
                              : AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 14),

          // User Auth Status
          StreamBuilder<UserModel?>(
            stream: firebase.userStream,
            initialData: firebase.currentUser,
            builder: (context, snapshot) {
              final user = snapshot.data ?? firebase.currentUser;
              final isGuest = user?.isAnonymous ?? true;

              if (!isGuest && user != null) {
                return PopupMenuButton<String>(
                  color: AppTheme.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.borderColor),
                  ),
                  tooltip: 'Account details',
                  onSelected: (val) {
                    if (val == 'logout') firebase.signOut();
                    if (val == 'pro') UpgradeModal.show(context);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        user.email ?? user.displayName ?? 'Signed in',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'pro',
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              size: 16, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Text('Manage Subscription',
                              style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded,
                              size: 16, color: AppTheme.error),
                          const SizedBox(width: 8),
                          Text('Sign Out',
                              style:
                                  GoogleFonts.inter(color: AppTheme.error)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.accent,
                          child: Text(
                            (user.displayName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user.shortName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await firebase.signInWithGoogle();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sign in notice: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.login_rounded, size: 14),
                label: Text(
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.borderColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 12),

          // Upgrade CTA
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => UpgradeModal.show(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Go Pro',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white),
              ),
            ),
          ).animate(delay: 200.ms).fadeIn().slideX(begin: 0.1, end: 0),
        ],
      ),
    );
  }
}

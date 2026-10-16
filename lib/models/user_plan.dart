class PlanLimits {
  const PlanLimits({
    required this.maxBytes,
    required this.dailyConversions,
    required this.linkTtl,
    required this.allowBatch,
    required this.permanentLinks,
  });

  final int maxBytes;
  final int? dailyConversions;
  final Duration? linkTtl;
  final bool allowBatch;
  final bool permanentLinks;

  static const free = PlanLimits(
    maxBytes: 50 * 1024 * 1024,
    dailyConversions: 3,
    linkTtl: Duration(hours: 24),
    allowBatch: false,
    permanentLinks: false,
  );

  static const pro = PlanLimits(
    maxBytes: 2 * 1024 * 1024 * 1024,
    dailyConversions: null,
    linkTtl: null,
    allowBatch: true,
    permanentLinks: true,
  );
}

class UserPlan {
  const UserPlan({
    required this.uid,
    required this.isPro,
    required this.conversionsToday,
    required this.quotaDayKey,
  });

  final String uid;
  final bool isPro;
  final int conversionsToday;
  final String quotaDayKey;

  PlanLimits get limits => isPro ? PlanLimits.pro : PlanLimits.free;

  int remainingToday() {
    final cap = limits.dailyConversions;
    if (cap == null) return 999999;
    return (cap - conversionsToday).clamp(0, cap);
  }

  bool get canConvert => remainingToday() > 0;
}

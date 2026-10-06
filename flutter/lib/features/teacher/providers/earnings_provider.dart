import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

/// Teacher earnings summary payload.
class EarningsSummary {
  const EarningsSummary({
    required this.totalEarningsIdr,
    required this.monthlyRecurringIdr,
    required this.pendingPayout,
    required this.recentActivity,
  });

  final double totalEarningsIdr;
  final double monthlyRecurringIdr;
  final double pendingPayout;
  final List<Map<String, dynamic>> recentActivity;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    return EarningsSummary(
      totalEarningsIdr: (json['total_earnings_idr'] as num?)?.toDouble() ?? 0.0,
      monthlyRecurringIdr:
          (json['monthly_recurring_idr'] as num?)?.toDouble() ?? 0.0,
      pendingPayout: (json['pending_payout'] as num?)?.toDouble() ?? 0.0,
      recentActivity: ((json['recent_activity'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>(),
    );
  }
}

/// Async provider for teacher earnings summary.
final earningsSummaryProvider = FutureProvider.autoDispose<EarningsSummary>((
  ref,
) async {
  final dio = ApiClient.create();
  final res = await dio.get('/commission/dashboard');
  return EarningsSummary.fromJson(res.data as Map<String, dynamic>);
});

/// Recent commission activity list (used on the dashboard and earnings page).
final recentActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final summary = await ref.watch(earningsSummaryProvider.future);
      return summary.recentActivity;
    });

/// Request a payout.
class PayoutNotifier extends StateNotifier<AsyncValue<void>> {
  PayoutNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<bool> request({required double amount, required String method}) async {
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient.create();
      await dio.post(
        '/commission/payouts',
        data: {'amount': amount, 'method': method},
      );
      ref.invalidate(earningsSummaryProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }
}

final payoutNotifierProvider =
    StateNotifierProvider<PayoutNotifier, AsyncValue<void>>((ref) {
      return PayoutNotifier(ref);
    });

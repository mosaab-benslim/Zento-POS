import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/dashboard_provider.dart';
import '../../../../core/providers/shift_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/constants/translations.dart';
import '../../../../core/utils/currency_helper.dart';

class OwnerSnapshot extends ConsumerWidget {
  const OwnerSnapshot({super.key});

  String _t(WidgetRef ref, String key) {
    final lang = ref.watch(languageProvider);
    return AppTranslations.t(lang, key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final shiftState = ref.watch(shiftProvider);
    final authState = ref.watch(authProvider);

    return dashboardAsync.when(
      data: (stats) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Active Shift Status (Wide)
            _buildActiveShiftCard(context, ref, shiftState, authState, stats.todayRevenue),
            
            const SizedBox(height: 16),

            // Row 2: Metric Cards (Revenue, Profit)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: _t(ref, 'lbl_today_revenue'),
                    value: CurrencyHelper.format(stats.todayRevenue.round()),
                    icon: Icons.payments_outlined,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    title: _t(ref, 'lbl_today_profit'),
                    value: CurrencyHelper.format(stats.todayProfit.round()),
                    icon: Icons.trending_up,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Row 3: Cash Difference (Only if not zero)
            if (stats.cashDifference != 0) ...[
              _buildCashDiffCard(context, ref, stats.cashDifference),
              const SizedBox(height: 16),
            ],

            // Row 4: Low Stock Quick View
            if (stats.lowStockItems.isNotEmpty)
              _buildLowStockSnapshot(context, ref, stats.lowStockItems),
          ],
        );
      },
      loading: () => const Center(child: LinearProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildActiveShiftCard(BuildContext context, WidgetRef ref, ShiftState shiftState, AuthState authState, double currentRevenue) {
    // 🔥 Dashboard Logic: Admin sees ANY active shift in the system
    final shift = shiftState.activeShift ?? shiftState.globalShift;
    final isOpen = shift != null;
    final color = isOpen ? Colors.deepPurple : Colors.blueGrey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(isOpen ? Icons.stars_rounded : Icons.pause_circle_outline, color: color, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(ref, 'lbl_active_shift').toUpperCase(),
                      style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOpen ? (shift.userName ?? 'Unknown') : _t(ref, 'status_closed'),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              if (isOpen)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_filled, size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('hh:mm a').format(shift.startTime),
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (isOpen) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t(ref, 'lbl_expected_cash'), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyHelper.format((shift.openingCash + currentRevenue).round()),
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color, letterSpacing: -1),
                    ),
                  ],
                ),
                Icon(Icons.account_balance_wallet_rounded, color: color.withOpacity(0.3), size: 40),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashDiffCard(BuildContext context, WidgetRef ref, double diff) {
    final isShortage = diff < 0;
    final color = isShortage ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(isShortage ? Icons.trending_down : Icons.trending_up, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Text(
            isShortage ? _t(ref, 'lbl_shortage') : _t(ref, 'lbl_overage'),
            style: TextStyle(color: color.withAlpha(200), fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            CurrencyHelper.format(diff.abs().round()),
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockSnapshot(BuildContext context, WidgetRef ref, List lowStockItems) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
              const SizedBox(width: 12),
              Text(
                _t(ref, 'lbl_low_stock_alerts').toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange.shade900, fontSize: 13, letterSpacing: 1),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${lowStockItems.length} items',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red.shade900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...lowStockItems.take(3).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    Text('${item.stockQuantity}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(' / ${item.alertLevel}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

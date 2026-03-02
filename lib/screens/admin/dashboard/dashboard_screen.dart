import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/translations.dart';
import '../../../core/providers/dashboard_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/utils/currency_helper.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _t(WidgetRef ref, String key) {
    final lang = ref.watch(languageProvider);
    return AppTranslations.t(lang, key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final shiftState = ref.watch(shiftProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t(ref, 'dashboard_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(dashboardProvider),
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (stats) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(ref, 'welcome_admin'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                
                // 1. Key Metrics Grid
                GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStatCard(
                      context,
                      title: _t(ref, 'lbl_today_revenue'),
                      value: CurrencyHelper.format(stats.todayRevenue.round()),
                      icon: Icons.attach_money,
                      color: Colors.green,
                    ),
                    _buildStatCard(
                      context,
                      title: _t(ref, 'lbl_today_profit'),
                      value: CurrencyHelper.format(stats.todayProfit.round()),
                      icon: Icons.trending_up,
                      color: Colors.blue,
                    ),
                    _buildStatCard(
                      context,
                      title: _t(ref, 'lbl_active_shift'),
                      value: shiftState.activeShift != null ? 'OPEN' : 'CLOSED',
                      subtitle: shiftState.activeShift != null 
                          ? '${_t(ref, 'lbl_opened_by')}: ${shiftState.activeShift!.userId}' // ideally need user name map
                          : _t(ref, 'msg_no_shift'),
                      icon: Icons.store,
                      color: shiftState.activeShift != null ? Colors.orange : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 2. Charts & Alerts Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Monthly Revenue Graph
                    Expanded(
                      flex: 2,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_t(ref, 'lbl_monthly_revenue'), style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 300,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: stats.monthlyRevenue.values.isEmpty 
                                        ? 1000 
                                        : stats.monthlyRevenue.values.reduce((a, b) => a > b ? a : b) * 1.2,
                                    barTouchData: BarTouchData(enabled: true),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            return Text(value.toInt().toString());
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: stats.monthlyRevenue.entries.map((e) {
                                      return BarChartGroupData(
                                        x: e.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: e.value,
                                            color: Colors.blueAccent,
                                            width: 16,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Low Stock Alerts
                    Expanded(
                      flex: 1,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_t(ref, 'lbl_low_stock_alerts'), style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              if (stats.lowStockItems.isEmpty)
                                Text(_t(ref, 'msg_all_good_stock'), style: const TextStyle(color: Colors.green)),
                              ...stats.lowStockItems.map((item) => ListTile(
                                leading: const Icon(Icons.warning, color: Colors.orange),
                                title: Text(item.name),
                                subtitle: Text('${_t(ref, 'col_stock')}: ${item.stockQuantity} / ${item.alertLevel}'),
                                trailing: Text(
                                  CurrencyHelper.format(item.priceCents), 
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}

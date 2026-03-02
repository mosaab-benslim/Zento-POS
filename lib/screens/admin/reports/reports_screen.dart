import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zento_pos/core/repositories/order_repository.dart';
import 'package:zento_pos/core/models/order_model.dart';
import 'package:zento_pos/core/repositories/app_settings_repository.dart';
import 'package:zento_pos/core/utils/currency_helper.dart';
import 'package:zento_pos/core/utils/pdf_report_service.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/core/repositories/expense_repository.dart';
import 'package:zento_pos/main.dart';
import 'package:intl/intl.dart';
import 'package:zento_pos/core/models/shift_model.dart';
import 'package:zento_pos/core/repositories/shift_repository.dart';
import 'package:zento_pos/core/constants/translations.dart';

enum ReportFilter { today, week, month, last7Days }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isLoading = true;
  ReportFilter _currentFilter = ReportFilter.today;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _categoryData = [];
  List<OrderModel> _recentOrders = [];
  double _totalExpenses = 0.0;
  List<ShiftModel> _shifts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_currentFilter) {
      case ReportFilter.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case ReportFilter.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: DateTime(start.year, start.month, start.day), end: end);
      case ReportFilter.month:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case ReportFilter.last7Days:
        final start = now.subtract(const Duration(days: 7));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: DateTime(start.year, start.month, start.day), end: end);
    }
}

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = ref.read(orderRepositoryProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);
    final range = _getDateRange();

    final results = await Future.wait<dynamic>([
      repo.getSummaryStats(start: range.start, end: range.end),
      repo.getTopProducts(start: range.start, end: range.end),
      repo.getCategoryBreakdown(start: range.start, end: range.end),
      repo.getAllOrders(start: range.start, end: range.end),
      expenseRepo.getTotalExpenses(start: range.start, end: range.end),
      ref.read(shiftRepositoryProvider).getShiftHistory(),
    ]);

    if (mounted) {
      final summary = results[0] as Map<String, dynamic>;
      final recentOrders = results[3] as List<OrderModel>;
      final allShifts = results[5] as List<ShiftModel>;

      setState(() {
        _summary = summary;
        _topProducts = (results[1] as List<Map<String, dynamic>>);
        _categoryData = (results[2] as List<Map<String, dynamic>>);
        _recentOrders = recentOrders;
        _totalExpenses = results[4] as double;
        _shifts = allShifts.where((s) => s.startTime.isAfter(range.start) && s.startTime.isBefore(range.end)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    final settingsRepo = ref.read(appSettingsRepositoryProvider);
    final settings = await settingsRepo.getSettings();
    final range = _getDateRange();

    await PdfReportService.generateAndPrintReport(
      storeName: settings?.storeName ?? "SOLID POS",
      start: range.start,
      end: range.end,
      summary: _summary ?? {},
      categories: _categoryData,
      topProducts: _topProducts,
      currency: settings?.currency ?? "USD",
    );
  }

  String _t(String key) {
    final lang = ref.watch(languageProvider);
    final text = {
      'title': {AppLanguage.en: 'Business Analytics', AppLanguage.fr: 'Analyse d\'Entreprise', AppLanguage.ar: 'تحليلات الأعمال'},
      'revenue': {AppLanguage.en: 'Total Revenue', AppLanguage.fr: 'Chiffre d\'Affaires', AppLanguage.ar: 'إجمالي الإيرادات'},
      'orders': {AppLanguage.en: 'Total Orders', AppLanguage.fr: 'Total des Commandes', AppLanguage.ar: 'إجمالي الطلبات'},
      'avg_ticket': {AppLanguage.en: 'Avg. Ticket', AppLanguage.fr: 'Panier Moyen', AppLanguage.ar: 'متوسط الفاتورة'},
      'categories': {AppLanguage.en: 'Sales by Category', AppLanguage.fr: 'Ventes par Catégorie', AppLanguage.ar: 'المبيعات حسب الصنف'},
      'top_products': {AppLanguage.en: 'Best Sellers', AppLanguage.fr: 'Meilleures Ventes', AppLanguage.ar: 'الأكثر مبيعاً'},
      'btn_export': {AppLanguage.en: 'Export PDF', AppLanguage.fr: 'Exporter PDF', AppLanguage.ar: 'تصدير PDF'},
      'filter_today': {AppLanguage.en: 'Today', AppLanguage.fr: 'Aujourd\'hui', AppLanguage.ar: 'اليوم'},
      'filter_week': {AppLanguage.en: 'This Week', AppLanguage.fr: 'Cette Semaine', AppLanguage.ar: 'هذا الأسبوع'},
      'filter_month': {AppLanguage.en: 'This Month', AppLanguage.fr: 'Ce Mois', AppLanguage.ar: 'هذا الشهر'},
      'filter_7days': {AppLanguage.en: 'Last 7 Days', AppLanguage.fr: '7 Derniers Jours', AppLanguage.ar: 'آخر 7 أيام'},
      'recent_orders': {AppLanguage.en: 'Recent Transactions (Audit)', AppLanguage.fr: 'Transactions Récentes (Audit)', AppLanguage.ar: 'المعاملات الأخيرة'},
      'net_profit': {AppLanguage.en: 'Net Profit', AppLanguage.fr: 'Bénéfice Net', AppLanguage.ar: 'صافي الربح'},
      'expenses': {AppLanguage.en: 'Non-Food Expenses', AppLanguage.fr: 'Dépenses', AppLanguage.ar: 'المصاريف'},
    };
    return text[key]?[lang] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_t('title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: Text(_t('btn_export')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterButton(ReportFilter.today, _t('filter_today')),
                const SizedBox(width: 12),
                _buildFilterButton(ReportFilter.week, _t('filter_week')),
                const SizedBox(width: 12),
                _buildFilterButton(ReportFilter.last7Days, _t('filter_7days')),
                const SizedBox(width: 12),
                _buildFilterButton(ReportFilter.month, _t('filter_month')),
              ],
            ),
          ),

          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. KPI Cards
                      Row(
                        children: [
                          _buildKPICard(
                            _t('revenue'),
                            CurrencyHelper.format(((_summary?['total_revenue'] ?? 0) as num).round()),
                            Icons.payments,
                            Colors.green,
                          ),
                          const SizedBox(width: 16),
                          _buildKPICard(
                            _t('orders'),
                            (_summary?['order_count'] ?? 0).toString(),
                            Icons.shopping_bag,
                            Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          _buildKPICard(
                            _t('avg_ticket'),
                            CurrencyHelper.format(((_summary?['avg_order'] ?? 0) as num).round()),
                            Icons.receipt_long,
                            Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildProfitSection(ref),
                      const SizedBox(height: 32),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 3. Category Summary
                          Expanded(
                            flex: 1,
                            child: _buildSection(
                              _t('categories'),
                              _categoryData.isEmpty
                                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No records for this period")))
                                  : Column(
                                      children: _categoryData.map((data) => ListTile(
                                        title: Text(data['category'].toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
                                        trailing: Text(CurrencyHelper.format((data['revenue'] as num).round()), style: const TextStyle(fontWeight: FontWeight.bold)),
                                        dense: true,
                                      )).toList(),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          // 4. Best Sellers
                          Expanded(
                            flex: 1,
                            child: _buildSection(
                              _t('top_products'),
                              _topProducts.isEmpty
                                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No data available")))
                                  : Column(
                                      children: _topProducts.take(5).map((data) => ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.blue.withOpacity(0.1),
                                          child: Text(data['qty'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        title: Text(data['name'].toString()),
                                        dense: true,
                                      )).toList(),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildShiftPerformanceSection(),
                      const SizedBox(height: 32),

                      // 5. 🔥 NEW: Auditing Section (Recent Orders)
                      _buildSection(
                        _t('recent_orders'),
                        _recentOrders.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No transactions found")))
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentOrders.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final order = _recentOrders[index];
                                final isVoided = order.status == OrderStatus.voided;
                                // Accurate time with seconds
                                final time = DateFormat('HH:mm:ss').format(order.createdAt.toLocal());
                                
                                return ListTile(
                                  dense: true,
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isVoided ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "#${order.queueNumber}", 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isVoided ? Colors.red : Colors.blue.shade800,
                                      )
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(time, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 8),
                                      if (isVoided)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                          child: const Text("VOID", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    "${order.orderType == OrderType.dineIn ? "SUR PLACE" : "EMPORTER"}${isVoided ? ' (ANNULÉ)' : ''}",
                                    style: TextStyle(color: isVoided ? Colors.red.shade300 : Colors.grey),
                                  ),
                                  trailing: Text(
                                    CurrencyHelper.format(order.totalCents),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      color: isVoided ? Colors.red.shade300 : Colors.blueGrey,
                                      decoration: isVoided ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(ReportFilter filter, String label) {
    final isSelected = _currentFilter == filter;
    return InkWell(
      onTap: () {
        setState(() => _currentFilter = filter);
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C3E50) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), overflow: TextOverflow.ellipsis),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftPerformanceSection() {
    return _buildSection(
      "Shift Performance",
      _shifts.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No shifts in this period")))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _shifts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final shift = _shifts[index];
                final isClosed = shift.status == ShiftStatus.closed;
                final diff = shift.cashDifference;
                
                return ListTile(
                  title: Text("Shift #${shift.id} - ${DateFormat('HH:mm').format(shift.startTime)}"),
                  subtitle: Text(isClosed ? "Status: CLOSED" : "Status: OPEN"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(CurrencyHelper.format(shift.totalSales.round()), style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (isClosed && diff != 0)
                        Text(
                          "${diff > 0 ? '+' : ''}${diff.toStringAsFixed(2)} DZD",
                          style: TextStyle(color: diff > 0 ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const Divider(height: 1),
          child,
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfitSection(WidgetRef ref) {
    final revenue = ((_summary?['total_revenue'] ?? 0) as num).toDouble();
    final netProfit = revenue - _totalExpenses; // Simple net profit for now (Revenue - Expenses)
    // Future: Revenue - COGS - Expenses
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t('net_profit'), style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
              Text(
                CurrencyHelper.format(netProfit.round()),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildProfitDetail(_t('revenue'), revenue, Colors.white70),
              const SizedBox(height: 8),
              _buildProfitDetail("- ${_t('expenses')}", _totalExpenses, Colors.red.shade200),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfitDetail(String label, double amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 13)),
        const SizedBox(width: 12),
        Text(
          CurrencyHelper.format(amount.round()),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}

// lib/screens/admin/shifts/shift_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/repositories/shift_repository.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/constants/translations.dart';

class ShiftHistoryScreen extends ConsumerStatefulWidget {
  const ShiftHistoryScreen({super.key});

  @override
  ConsumerState<ShiftHistoryScreen> createState() => _ShiftHistoryScreenState();
}

class _ShiftHistoryScreenState extends ConsumerState<ShiftHistoryScreen> {
  final _repository = ShiftRepository();
  List<ShiftModel> _shifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _isLoading = true);
    final shifts = await _repository.getShiftHistory();
    setState(() {
      _shifts = shifts;
      _isLoading = false;
    });
  }

  String _t(String key) {
    final lang = ref.watch(languageProvider);
    return AppTranslations.t(lang, key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('shift_history')),
        actions: [
          IconButton(onPressed: _loadShifts, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shifts.isEmpty
              ? Center(child: Text(_t('msg_no_data')))
              : ListView.builder(
                  itemCount: _shifts.length,
                  itemBuilder: (context, index) {
                    final shift = _shifts[index];
                    return _ShiftCard(shift: shift, t: _t);
                  },
                ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final ShiftModel shift;
  final String Function(String) t;

  const _ShiftCard({required this.shift, required this.t});

  @override
  Widget build(BuildContext context) {
    final isClosed = shift.status == ShiftStatus.closed;
    final diff = shift.cashDifference;
    final hasDiff = diff != 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        subtitle: Text(
          isClosed 
            ? "${t('status_closed')} - ${DateFormat('dd/MM HH:mm').format(shift.endTime!)}"
            : "${t('status_open')} - ${DateFormat('dd/MM HH:mm').format(shift.startTime)}",
          style: TextStyle(color: isClosed ? Colors.grey : Colors.green, fontWeight: FontWeight.bold),
        ),
        title: Row(
          children: [
            Text("Shift #${shift.id ?? '?'}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (isClosed && hasDiff)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: diff > 0 ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${diff > 0 ? '+' : ''}${diff.toStringAsFixed(2)} DZD",
                  style: TextStyle(color: diff > 0 ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildRow(t('lbl_opening_cash'), shift.openingCash),
                if (isClosed) ...[
                  _buildRow(t('lbl_cash_sales'), shift.totalCashSales),
                  _buildRow(t('lbl_card_sales'), shift.totalCardSales),
                  const Divider(),
                  _buildRow(t('lbl_expected_cash'), shift.expectedCash, isBold: true),
                  _buildRow(t('lbl_actual_cash'), shift.closingCash ?? 0, isBold: true),
                  _buildRow(t('lbl_difference'), shift.cashDifference, color: hasDiff ? (diff > 0 ? Colors.green : Colors.red) : null, isBold: true),
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRow(String label, double value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            "${value.toStringAsFixed(2)} DZD",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

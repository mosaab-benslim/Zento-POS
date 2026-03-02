// lib/screens/pos/shifts/shift_dialog_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/constants/translations.dart';
import '../../../core/repositories/shift_repository.dart';

class ShiftDialogs {
  static String _t(WidgetRef ref, String key) {
    final lang = ref.watch(languageProvider);
    return AppTranslations.t(lang, key);
  }

  static void showOpenShift(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_t(ref, 'btn_open_shift')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_t(ref, 'lbl_opening_cash')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixText: 'DZD',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t(ref, 'btn_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              ref.read(shiftProvider.notifier).openShift(amount);
              Navigator.pop(context);
            },
            child: Text(_t(ref, 'btn_save')),
          ),
        ],
      ),
    );
  }

  static void showCloseShift(BuildContext context, WidgetRef ref) {
    final shiftState = ref.read(shiftProvider);
    final activeShift = shiftState.activeShift;
    if (activeShift == null) return;

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t(ref, 'btn_close_shift')),
        content: FutureBuilder<Map<String, int>>(
          future: ref.read(shiftRepositoryProvider).getShiftSummary(activeShift.id!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            final summary = snapshot.data ?? {};
            final cashSales = (summary['cash'] ?? 0) / 100.0;
            final cardSales = (summary['card'] ?? 0) / 100.0;
            final cashOut = (summary['cashOut'] ?? 0) / 100.0;
            final expectedCash = activeShift.openingCash + cashSales - cashOut;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryRow(ref, 'lbl_opening_cash', activeShift.openingCash),
                  _buildSummaryRow(ref, 'lbl_cash_sales', cashSales, prefix: '+'),
                  _buildSummaryRow(ref, 'card', cardSales, prefix: '+'), // Re-using 'card' translation
                  _buildSummaryRow(ref, 'lbl_money_out', cashOut, prefix: '-'),
                  const Divider(),
                  _buildSummaryRow(ref, 'lbl_expected_cash', expectedCash, isBold: true),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(_t(ref, 'lbl_actual_cash'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixText: 'DZD',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t(ref, 'btn_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              ref.read(shiftProvider.notifier).closeShift(amount);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_t(ref, 'msg_shift_closed_success'))),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(_t(ref, 'btn_close_shift')),
          ),
        ],
      ),
    );
  }

  static Widget _buildSummaryRow(WidgetRef ref, String key, double amount, {String? prefix, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_t(ref, key), style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text(
            "${prefix ?? ''} ${amount.toStringAsFixed(2)} DZD",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: prefix == '-' ? Colors.red : (prefix == '+' ? Colors.green : null),
            ),
          ),
        ],
      ),
    );
  }
}

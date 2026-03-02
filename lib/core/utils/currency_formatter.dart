import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _currencyFormat = NumberFormat.currency(symbol: 'DA', decimalDigits: 2, customPattern: '#,##0.00 \u00A4');

  /// Converts cents (int) to formatted string (e.g. 1000 -> 10.00 DA)
  static String formatCents(int cents) {
    final double amount = cents / 100.0;
    return _currencyFormat.format(amount);
  }

  /// Converts decimal string to cents (e.g. "10.50" -> 1050)
  static int parseToCents(String value) {
    if (value.isEmpty) return 0;
    final double? amount = double.tryParse(value.replaceAll(',', ''));
    if (amount == null) return 0;
    return (amount * 100).round();
  }
}

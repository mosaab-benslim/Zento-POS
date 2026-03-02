import 'package:intl/intl.dart';

class CurrencyHelper {
  static final _formatter = NumberFormat("#,##0", "en_US"); 

  static String format(int amount, {bool isPrinter = false}) {
    final clean = _formatter.format(amount).replaceAll(',', ' ');
    if (isPrinter) return "$clean DZD";
    
    // \u200E is the Left-to-Right Mark (LRM) which prevents RTL locales from flipping the currency parts on screen.
    return "\u200E$clean DZD";
  }
}

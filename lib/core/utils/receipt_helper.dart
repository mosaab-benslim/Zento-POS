import 'dart:io';
import 'package:flutter/material.dart';
import 'package:zento_pos/core/models/app_settings_model.dart';
import 'package:zento_pos/core/models/order_model.dart';
import 'package:zento_pos/core/models/order_item_model.dart';
import 'package:zento_pos/core/utils/currency_helper.dart';
import 'package:zento_pos/core/services/printer_service.dart';
import 'package:zento_pos/core/constants/translations.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:intl/intl.dart' hide TextDirection;

class ReceiptHelper {
  static Future<void> showReceiptPreview({
    required BuildContext context,
    required OrderModel order,
    required List<OrderItem> items,
    required AppSettings settings,
    required AppLanguage lang,
    bool isKitchen = false,
    bool openCashDrawer = false,
    bool forceSolitaryCustomer = false, 
  }) async {
    // --- 0. SAFETY GATE (FOR AUTO-PRINT KOT) ---
    // If we're doing a full flow (not forceSolitaryCustomer) and KOT is enabled
    if (!forceSolitaryCustomer && settings.enableKitchenPrinter && settings.autoPrintKot) {
      final isReachable = await PrinterService.verifyConnectivity(
        address: settings.kitchenPrinterAddress,
        type: settings.kitchenPrinterType ?? 'usb',
      );

      if (!isReachable) {
        final proceed = await _showSafetyGateDialog(context, lang);
        if (proceed != true) return; // User cancelled checkout
      }
    }

    // --- 1. KITCHEN ONLY ---
    if (isKitchen) {
      await PrinterService.printReceipt(
        order: order,
        items: items,
        storeName: settings.storeName,
        logoPath: settings.receiptLogoPath,
        isKitchen: true,
        customAddress: settings.kitchenPrinterAddress,
        type: settings.kitchenPrinterType ?? 'usb',
      );
      if (context.mounted) _showSingleDialog(context, order, items, settings, lang, true, false);
      return;
    }

    // --- 2. CUSTOMER ONLY (RESUMED/MANUAL) ---
    if (forceSolitaryCustomer) {
      await PrinterService.printReceipt(
        order: order,
        items: items,
        storeName: settings.storeName,
        logoPath: settings.receiptLogoPath,
        isKitchen: false,
        openDrawer: openCashDrawer,
      );
      if (context.mounted) _showSingleDialog(context, order, items, settings, lang, false, openCashDrawer);
      return;
    }

    // --- 3. BOTH (STANDARD CHECKOUT) ---
    // Print Kitchen
    if (settings.enableKitchenPrinter) {
        await PrinterService.printReceipt(
          order: order,
          items: items,
          storeName: settings.storeName,
          logoPath: settings.receiptLogoPath,
          isKitchen: true,
          customAddress: settings.kitchenPrinterAddress,
          type: settings.kitchenPrinterType ?? 'usb',
        );
    }

    // Print Customer
    await PrinterService.printReceipt(
      order: order,
      items: items,
      storeName: settings.storeName,
      logoPath: settings.receiptLogoPath,
      isKitchen: false,
      openDrawer: openCashDrawer,
    );

    // Show Dialogs
    if (context.mounted) {
      if (settings.enableKitchenPrinter) {
          await _showSingleDialog(context, order, items, settings, lang, true, false);
      }
      if (context.mounted) {
          await _showSingleDialog(context, order, items, settings, lang, false, openCashDrawer);
      }
    }
  }

  static Future<bool?> _showSafetyGateDialog(BuildContext context, AppLanguage lang) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(AppTranslations.t(lang, 'err_kitchen_printer')),
          ],
        ),
        content: Text(AppTranslations.t(lang, 'err_printer_unreachable')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppTranslations.t(lang, 'btn_cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppTranslations.t(lang, 'btn_confirm_anyway')),
          ),
        ],
      ),
    );
  }

  static Future<void> _showSingleDialog(BuildContext context, OrderModel order, List<OrderItem> items, AppSettings settings, AppLanguage lang, bool isKitchen, bool openCashDrawer) async {
    return showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Container(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. LOGO & HEADER
                  if (settings.receiptLogoPath != null && settings.receiptLogoPath!.isNotEmpty && !isKitchen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Image.file(
                        File(settings.receiptLogoPath!),
                        height: 60,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  
                  Text(settings.storeName.toUpperCase(), 
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.2)),
                  Text(isKitchen ? "BON DE CUISINE" : "REÇU / TAX INVOICE", 
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                  const Divider(thickness: 1, height: 20),
  
                  // 2. PROMINENT ORDER NUMBER
                  const Text("ORDER NUMBER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  Text(order.queueNumber.toString().padLeft(3, '0'), 
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 10),
                  
                  // 3. METADATA
                  const Divider(thickness: 1, height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text("DATE: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}", 
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          order.orderType == OrderType.dineIn ? "SUR PLACE" : (order.orderType == OrderType.takeaway ? "EMPORTER" : "LIVRAISON"),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (order.tableName != null && order.tableName!.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text("TABLE: ${order.tableName}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                      ],
                    ],
                  ),
                  const Divider(thickness: 1, height: 10),
  
                  // 4. ITEMS TABLE (Standard Qté | Name | Total)
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const SizedBox(width: 40, child: Text("Qté", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        const Expanded(child: Text("Désignation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        if (!isKitchen) const Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
                  const DottedDivider(),
                  const SizedBox(height: 5),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 40, child: Text("${item.quantity} x", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(
                              child: Text(item.productName.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: isKitchen ? 15 : 13)),
                            ),
                            if (!isKitchen) 
                              Text(CurrencyHelper.format(item.priceCents * item.quantity).replaceAll(' DZD', ''),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        if (item.modifiers != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 40, top: 2),
                            child: Text("+ ${item.modifiers}", style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  )),
  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: DottedDivider(),
                  ),
  
                  // 5. TOTALS (Standard)
                  if (!isKitchen) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("MODE DE PAIEMENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(
                          order.paymentMethod == PaymentMethod.cash 
                              ? "ESPÈCES" 
                              : (order.paymentMethod == PaymentMethod.card ? "CARTE" : "LIVRAISON"),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppTranslations.t(lang, 'lbl_grand_total'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          Text(
                            CurrencyHelper.format(order.totalCents),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppTranslations.t(lang, 'lbl_thank_you'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    const Text("Zento POS - Stability First", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
  
                  if (openCashDrawer && !isKitchen) ...[
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.open_in_new, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Text(AppTranslations.t(lang, 'lbl_drawer_pulse'), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppTranslations.t(lang, 'btn_finish'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey)),
            );
          }),
        );
      },
    );
  }
}

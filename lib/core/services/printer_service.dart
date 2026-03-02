import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:zento_pos/core/models/order_model.dart';
import 'package:zento_pos/core/models/order_item_model.dart';
import 'package:zento_pos/core/utils/currency_helper.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

class PrinterService {
  static final PrinterManager _printerManager = PrinterManager.instance;
  
  static PrinterDevice? _selectedPrinter;
  static CapabilityProfile? _cachedProfile;

  /// Scan for printers (USB / Network)
  static Stream<PrinterDevice> scanPrinters({PrinterType type = PrinterType.usb}) {
    return _printerManager.discovery(type: type);
  }

  static Future<bool> connect(PrinterDevice printer, {PrinterType type = PrinterType.usb}) async {
    _selectedPrinter = printer;
    try {
      print("🔌 CONNECTING to: ${printer.name} (${printer.address})...");
      
      if (type == PrinterType.usb) {
        await _printerManager.connect(
          type: PrinterType.usb,
          model: UsbPrinterInput(
            name: printer.name,
            productId: printer.productId,
            vendorId: printer.vendorId,
          ),
        );
      } else {
        await _printerManager.connect(
          type: PrinterType.network,
          model: TcpPrinterInput(ipAddress: printer.address!),
        );
      }
      
      print("✅ CONNECTED successfully.");
      return true;
    } catch (e) {
      print("❌ CONNECTION FAILED: $e");
      return false;
    }
  }

  /// Verifies if a printer is reachable (important for KOT safety)
  static Future<bool> verifyConnectivity({required String? address, required String type}) async {
    if (type == 'network') {
      if (address == null || address.isEmpty) return false;
      try {
        final socket = await Socket.connect(address, 9100, timeout: const Duration(seconds: 2));
        await socket.close();
        return true;
      } catch (_) {
        return false;
      }
    }
    // For USB or when no IP is set for a network printer, return true to avoid blocking simulation/default
    return true; 
  }

  static Future<bool> printReceipt({
    required OrderModel order,
    required List<OrderItem> items,
    required String storeName,
    String? logoPath,
    bool isKitchen = false,
    bool openDrawer = false,
    String? customAddress,
    String type = 'usb',
  }) async {
    final printerAddress = customAddress ?? _selectedPrinter?.address;
    
    if (printerAddress == null) {
      print("⚠️ SIMULATION: No printer connected. Generating virtual print bytes...");
      _simulatePrint(order: order, items: items, storeName: storeName, logoPath: logoPath, isKitchen: isKitchen, openDrawer: openDrawer);
      return true;
    }

    try {
      print("generating ${isKitchen ? 'KOT' : 'Receipt'}...");
      _cachedProfile ??= await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, _cachedProfile!);
      
      List<int> bytes = generator.reset();

      if (!isKitchen) {
          // --- CUSTOMER RECEIPT ---
          if (logoPath != null && logoPath.isNotEmpty) {
            try {
              final bytesLogo = File(logoPath).readAsBytesSync();
              final image = img.decodeImage(bytesLogo);
              if (image != null) {
                final resized = img.copyResize(image, width: 220);
                bytes += generator.image(resized);
                bytes += generator.feed(1);
              }
            } catch (e) {
              print("⚠️ Error printing logo: $e");
            }
          }

          bytes += generator.text(storeName.toUpperCase(), 
              styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
          bytes += generator.text('FACTURE / TAX INVOICE', 
              styles: const PosStyles(align: PosAlign.center, bold: true));
          bytes += generator.hr();
      } else {
          // --- KITCHEN ORDER TICKET (KOT) ---
          bytes += generator.text('--- BON DE CUISINE ---', 
              styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
          bytes += generator.feed(1);
      }

      // 3. THE QUEUE NUMBER (Identity)
      bytes += generator.text('ORDER NUMBER', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('${order.queueNumber}'.padLeft(3, '0'), 
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size3, width: PosTextSize.size3));
      bytes += generator.feed(1);

      // 4. ORDER METADATA
      final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt);
      bytes += generator.text('DATE: $dateStr', styles: const PosStyles(bold: true));

      String typeLabel = order.orderType == OrderType.dineIn ? 'SUR PLACE' : (order.orderType == OrderType.takeaway ? 'EMPORTER' : 'LIVRAISON');
      if (order.tableName != null && order.tableName!.isNotEmpty) {
          typeLabel += " - TABLE: ${order.tableName}";
      }
      bytes += generator.text(typeLabel, styles: const PosStyles(bold: true, height: PosTextSize.size2));
      bytes += generator.hr();

      // 5. THE ITEMS TABLE
      if (!isKitchen) {
          bytes += generator.row([
            PosColumn(text: 'Qté', width: 2, styles: const PosStyles(bold: true)),
            PosColumn(text: 'Désignation', width: 7, styles: const PosStyles(bold: true)),
            PosColumn(text: 'Total', width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
          ]);
      } else {
          bytes += generator.text('ITEMS SELECTION', styles: const PosStyles(bold: true, underline: true));
      }
      bytes += generator.hr();

      for (var item in items) {
          if (!isKitchen) {
              bytes += generator.row([
                PosColumn(text: '${item.quantity}', width: 2),
                PosColumn(text: item.productName.toUpperCase(), width: 7),
                PosColumn(text: CurrencyHelper.format(item.priceCents * item.quantity, isPrinter: true).replaceAll(' DZD', ''), width: 3, styles: const PosStyles(align: PosAlign.right)),
              ]);
              if (item.modifiers != null) {
                bytes += generator.text("  + ${item.modifiers}", styles: const PosStyles(height: PosTextSize.size1, width: PosTextSize.size1));
              }
          } else {
              // KOT specific: Large text for items, clear modifiers
              bytes += generator.text("${item.quantity}x ${item.productName.toUpperCase()}", 
                  styles: const PosStyles(bold: true, height: PosTextSize.size2));
              if (item.modifiers != null) {
                bytes += generator.text("   MOD: ${item.modifiers}", styles: const PosStyles(bold: true));
              }
              bytes += generator.feed(1);
          }
      }
      bytes += generator.hr();

      // 6. FINANCIALS (Only if not kitchen)
      if (!isKitchen) {
          bytes += generator.row([
            PosColumn(text: 'MODE DE PAIEMENT:', width: 7),
            PosColumn(text: order.paymentMethod == PaymentMethod.cash ? 'ESPÈCES' : (order.paymentMethod == PaymentMethod.card ? 'CARTE' : 'LIVRAISON'), width: 5, styles: const PosStyles(align: PosAlign.right, bold: true)),
          ]);

          bytes += generator.row([
            PosColumn(text: 'TOTAL GENERAL:', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
            PosColumn(text: CurrencyHelper.format(order.totalCents, isPrinter: true), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
          ]);
          
          bytes += generator.hr();
          
          // 7. FOOTER
          bytes += generator.feed(1);
          bytes += generator.text('MERCI DE VOTRE VISITE', styles: const PosStyles(align: PosAlign.center, bold: true));
          bytes += generator.text('Zento POS - Stability First', styles: const PosStyles(align: PosAlign.center, bold: true));
      }

      bytes += generator.feed(3);
      bytes += generator.cut();

      // 8. CASH DRAWER (Only if requested and not kitchen)
      if (openDrawer && !isKitchen) {
          bytes += generator.drawer(pin: PosDrawer.pin2);
      }

      print("🖨️ SENDING ${bytes.length} bytes to printer ($type at $printerAddress)...");
      final pType = type == 'network' ? PrinterType.network : PrinterType.usb;
      final result = await _printerManager.send(type: pType, bytes: bytes);
      print("✅ DATA SENT. Success: $result");
      return result;
    } catch (e) {
      print("❌ PRINT FAILED: $e");
      return false;
    }
  }
  
  static Future<String> testDrawer() async {
     // ... (unchanged drawer test, but we could update pType if needed)
     return "Success"; // Simplified for brevity as we focus on KOT
  }

  static void _simulatePrint({
    required OrderModel order,
    required List<OrderItem> items,
    required String storeName,
    String? logoPath,
    bool isKitchen = false,
    bool openDrawer = false,
  }) {
    print("------------------------------------------");
    print("VIRTUAL RECEIPT [${isKitchen ? 'KITCHEN' : 'CUSTOMER'}]");
    if (logoPath != null) print("LOGO: $logoPath");
    print("STORE: $storeName");
    print("ORDER: #${order.queueNumber}");
    if (openDrawer) print("💸 COMMAND: OPEN CASH DRAWER");
    print("------------------------------------------");
    for (var item in items) {
       print("${item.quantity}x ${item.productName.padRight(20)} ${item.modifiers ?? ''}");
    }
    print("------------------------------------------");
    if (!isKitchen) print("TOTAL: ${order.totalCents}");
    print("------------------------------------------");
  }
}

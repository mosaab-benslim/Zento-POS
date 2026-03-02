import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../utils/currency_helper.dart';
import 'package:intl/intl.dart';

class PdfReceiptService {
  static Future<void> directPrint({
    required OrderModel order,
    required List<OrderItem> items,
    required String storeName,
    String? logoPath,
    bool isKitchen = false,
  }) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();
    
    pw.MemoryImage? logoImage;
    if (logoPath != null && File(logoPath).existsSync()) {
      final bytes = await File(logoPath).readAsBytes();
      logoImage = pw.MemoryImage(bytes);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return _buildReceiptSection(
            order: order,
            items: items,
            storeName: storeName,
            logoImage: logoImage,
            isKitchen: isKitchen,
          );
        },
      ),
    );

    await _executePrint(pdf);
  }

  static Future<void> printUnifiedReceipt({
    required OrderModel order,
    required List<OrderItem> items,
    required String storeName,
    String? logoPath,
  }) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();

    pw.MemoryImage? logoImage;
    if (logoPath != null && File(logoPath).existsSync()) {
      final bytes = await File(logoPath).readAsBytes();
      logoImage = pw.MemoryImage(bytes);
    }

    // Thermal Printer Paper Format
    const PdfPageFormat format = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm);

    // Page 1: 👨‍🍳 KITCHEN SLIP
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return _buildReceiptSection(
            order: order,
            items: items,
            storeName: storeName,
            isKitchen: true,
          );
        },
      ),
    );

    // Page 2: 📄 CUSTOMER RECEIPT
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return _buildReceiptSection(
            order: order,
            items: items,
            storeName: storeName,
            logoImage: logoImage,
            isKitchen: false,
          );
        },
      ),
    );

    await _executePrint(pdf);
  }

  static pw.Widget _buildReceiptSection({
    required OrderModel order,
    required List<OrderItem> items,
    required String storeName,
    pw.MemoryImage? logoImage,
    required bool isKitchen,
  }) {
    final timeStr = DateFormat('HH:mm:ss').format(order.createdAt.toLocal());
    final dateStr = DateFormat('yyyy-MM-dd').format(order.createdAt.toLocal());

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        if (!isKitchen) ...[
          if (logoImage != null)
            pw.Center(child: pw.Image(logoImage, height: 40, width: 40)),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text(storeName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Center(
            child: pw.Text("REÇU CLIENT", style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dotted),
        ] else ...[
          // COMPACT KITCHEN HEADER
          pw.Center(
            child: pw.Text("BON CUISINE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dotted),
        ],

        // Order Number
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text("N° COMMANDE", style: const pw.TextStyle(fontSize: 7)),
              pw.Text(
                order.queueNumber.toString().padLeft(3, '0'),
                style: pw.TextStyle(fontSize: isKitchen ? 40 : 34, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                order.orderType == OrderType.dineIn ? "SUR PLACE" : "EMPORTER",
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        if (!isKitchen) pw.SizedBox(height: 8) else pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dotted),

        // Info Row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text("Date: $dateStr", style: const pw.TextStyle(fontSize: 7)),
            pw.Text("Heure: $timeStr", style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
        pw.Text("Réf: #${order.id ?? '---'}", style: const pw.TextStyle(fontSize: 7)),
        pw.SizedBox(height: 8),

        // Items Table-like header
        pw.Row(
          children: [
            pw.SizedBox(width: 20, child: pw.Text("QT", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text("ARTICLE", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
            if (!isKitchen)
              pw.SizedBox(width: 50, child: pw.Text("PRIX", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        pw.Divider(thickness: 0.3),

        // Items List
        ...items.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 20, child: pw.Text("${item.quantity}x", style: pw.TextStyle(fontSize: isKitchen ? 11 : 9, fontWeight: isKitchen ? pw.FontWeight.bold : pw.FontWeight.normal))),
              pw.Expanded(
                child: pw.Text(
                  item.productName,
                  style: pw.TextStyle(fontSize: isKitchen ? 11 : 9, fontWeight: isKitchen ? pw.FontWeight.bold : pw.FontWeight.normal),
                ),
              ),
              if (!isKitchen)
                pw.SizedBox(
                  width: 50,
                  child: pw.Text(
                    CurrencyHelper.format(item.priceCents * item.quantity),
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
            ],
          ),
        )),

        pw.SizedBox(height: 8),
        pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dotted),

        if (!isKitchen) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("TOTAL", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                CurrencyHelper.format(order.totalCents),
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dotted),
          pw.SizedBox(height: 5),
          pw.Center(
            child: pw.Text("MERCI DE VOTRE VISITE !", style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
          ),
        ] else ...[
          pw.Center(
            child: pw.Text("*** CUISINE ***", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  static Future<void> _executePrint(pw.Document pdf) async {
    try {
      final printers = await Printing.listPrinters();
      
      print("🔍 FOUND ${printers.length} PRINTERS:");
      for (var p in printers) {
        print("   -> ${p.name} (Default: ${p.isDefault})");
      }

      final defaultPrinter = printers.firstWhere(
        (p) => p.isDefault,
        orElse: () => printers.isNotEmpty ? printers.first : throw Exception("No printers found"),
      );

      print("🚀 SENDING DIRECT PRINT TO: ${defaultPrinter.name}");

      await Printing.directPrintPdf(
        printer: defaultPrinter,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      print("❌ PRINTING FAILED: $e");
    }
  }
}

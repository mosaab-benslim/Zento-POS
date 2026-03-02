import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:zento_pos/core/utils/currency_helper.dart';
import 'package:intl/intl.dart';

class PdfReportService {
  static Future<void> generateAndPrintReport({
    required String storeName,
    required DateTime start,
    required DateTime end,
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> topProducts,
    required String currency,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final rangeStr = "${dateFormat.format(start)} to ${dateFormat.format(end)}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(storeName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Sales Report", style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Generated: ${dateFormat.format(DateTime.now())}"),
                    pw.Text("Period: $rangeStr", style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 32),
            pw.Divider(),
            pw.SizedBox(height: 24),

            // 1. Summary KPIs
            pw.Text("Executive Summary", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildKPICard("Total Revenue", CurrencyHelper.format(((summary['total_revenue'] ?? 0) as num).round()), currency),
                _buildKPICard("Total Orders", (summary['order_count'] ?? 0).toString(), ""),
                _buildKPICard("Avg. Ticket", CurrencyHelper.format(((summary['avg_order'] ?? 0) as num).round()), currency),
              ],
            ),
            pw.SizedBox(height: 40),

            // 2. Category Breakdown
            pw.Text("Sales by Category", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            _buildCategoryTable(categories, currency),
            pw.SizedBox(height: 40),

            // 3. Top Products
            pw.Text("Best Selling Products (Top 10)", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            _buildProductTable(topProducts),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          );
        },
      ),
    );

    // Show print preview / save dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'sales_report_${dateFormat.format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildKPICard(String label, String value, String currency) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildCategoryTable(List<Map<String, dynamic>> categories, String currency) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Category", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Revenue", style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
          ],
        ),
        ...categories.map((c) => pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(c['category'])),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(CurrencyHelper.format((c['revenue'] as num).round()), textAlign: pw.TextAlign.right)),
          ],
        )).toList(),
      ],
    );
  }

  static pw.Widget _buildProductTable(List<Map<String, dynamic>> products) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Product Name", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Quantity Sold", style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
          ],
        ),
        ...products.map((p) => pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(p['name'])),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(p['qty'].toString(), textAlign: pw.TextAlign.right)),
          ],
        )).toList(),
      ],
    );
  }
}

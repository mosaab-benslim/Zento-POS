import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zento_pos/core/constants/translations.dart';
import 'package:zento_pos/core/models/stock_batch_model.dart';
import 'package:zento_pos/core/models/stock_batch_item_model.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/core/repositories/stock_batch_repository.dart';

class StockHistoryScreen extends ConsumerStatefulWidget {
  const StockHistoryScreen({super.key});

  @override
  ConsumerState<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends ConsumerState<StockHistoryScreen> {
  String _t(String key) {
    final lang = ref.watch(languageProvider);
    return AppTranslations.data[key]?[lang] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(stockBatchRepositoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(_t('title_stock_history'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<StockBatch>>(
        future: repository.fetchAllBatches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final batches = snapshot.data ?? [];
          if (batches.isEmpty) {
            return Center(child: Text(_t('lbl_no_history'), style: const TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              return _BatchCard(batch: batch, t: _t);
            },
          );
        },
      ),
    );
  }
}

class _BatchCard extends ConsumerStatefulWidget {
  final StockBatch batch;
  final String Function(String) t;

  const _BatchCard({required this.batch, required this.t});

  @override
  ConsumerState<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends ConsumerState<_BatchCard> {
  bool _isExpanded = false;
  List<StockBatchItem>? _items;
  bool _loadingItems = false;

  Future<void> _toggleExpand() async {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded && _items == null) {
      setState(() => _loadingItems = true);
      final repo = ref.read(stockBatchRepositoryProvider);
      final items = await repo.fetchBatchItems(widget.batch.id!);
      setState(() {
        _items = items;
        _loadingItems = false;
      });
    }
  }

  void _showInvoice(String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(widget.t('lbl_view_invoice')),
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            onTap: _toggleExpand,
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: const Icon(Icons.inventory_2, color: Colors.blue),
            ),
            title: Text(widget.batch.supplierName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${widget.t('lbl_date')}: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.batch.receivedDate)}"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("DZD ${widget.batch.totalCost.toStringAsFixed(0)}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            if (_loadingItems)
              const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())
            else if (_items != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.batch.invoiceImagePath != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ElevatedButton.icon(
                          onPressed: () => _showInvoice(widget.batch.invoiceImagePath!),
                          icon: const Icon(Icons.image),
                          label: Text(widget.t('lbl_view_invoice')),
                        ),
                      ),
                    Text(widget.t('lbl_batch_details'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(widget.t('lbl_items'), style: const TextStyle(color: Colors.grey))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(widget.t('col_qty_received'), style: const TextStyle(color: Colors.grey))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(widget.t('col_subtotal'), style: const TextStyle(color: Colors.grey))),
                          ],
                        ),
                        ..._items!.map((item) => TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(item.ingredientName)),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text("${item.quantityReceived}")),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text("DZD ${item.subtotal.toStringAsFixed(0)}")),
                          ],
                        )),
                      ],
                    ),
                    if (widget.batch.notes != null && widget.batch.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(widget.t('lbl_notes'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(widget.batch.notes!, style: const TextStyle(color: Colors.grey)),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

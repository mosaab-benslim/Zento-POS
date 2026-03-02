import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zento_pos/core/constants/translations.dart';
import 'package:zento_pos/core/models/ingredient_model.dart';
import 'package:zento_pos/core/models/stock_batch_item_model.dart';
import 'package:zento_pos/core/models/stock_batch_model.dart';
import 'package:zento_pos/core/providers/ingredient_provider.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/core/repositories/stock_batch_repository.dart';

class StockReceivingScreen extends ConsumerStatefulWidget {
  const StockReceivingScreen({super.key});

  @override
  ConsumerState<StockReceivingScreen> createState() => _StockReceivingScreenState();
}

class _StockReceivingScreenState extends ConsumerState<StockReceivingScreen> {
  final _supplierCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _receivedDate = DateTime.now();
  String? _imagePath;
  
  final List<StockBatchItem> _batchItems = [];
  bool _isSaving = false;

  String _t(String key) {
    final lang = ref.watch(languageProvider);
    return AppTranslations.data[key]?[lang] ?? key;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      // Windows doesn't support ImageSource.camera without a delegate
      final source = Platform.isWindows ? ImageSource.gallery : ImageSource.camera;
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _imagePath = pickedFile.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _addItem() async {
    final ingredients = await ref.read(ingredientProvider.future);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _AddItemDialog(
        ingredients: ingredients,
        onAdd: (item) {
          setState(() => _batchItems.add(item));
        },
      ),
    );
  }

  double get _totalCost => _batchItems.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _commitBatch() async {
    if (_batchItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('msg_empty_batch')), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final batch = StockBatch(
        supplierName: _supplierCtrl.text.isEmpty ? 'Unknown' : _supplierCtrl.text,
        invoiceNumber: _invoiceCtrl.text.isEmpty ? 'N/A' : _invoiceCtrl.text,
        invoiceImagePath: _imagePath,
        totalCost: _totalCost,
        receivedDate: _receivedDate,
        notes: _notesCtrl.text,
      );

      await ref.read(stockBatchRepositoryProvider).receiveStock(batch, _batchItems);
      
      // Refresh inventory
      ref.invalidate(ingredientProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('msg_batch_success')), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${_t('msg_error')}: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(_t('title_stock_receiving'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ElevatedButton.icon(
                onPressed: _commitBatch,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_t('btn_commit_stock')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── LEFT PANEL: BATCH INFO ───
          SizedBox(
            width: 400,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t('section_basic'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _supplierCtrl,
                        decoration: InputDecoration(
                          labelText: _t('lbl_supplier'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.business),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _invoiceCtrl,
                        decoration: InputDecoration(
                          labelText: _t('lbl_invoice_no'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.receipt),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Date: ${DateFormat('yyyy-MM-dd').format(_receivedDate)}"),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _receivedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => _receivedDate = date);
                        },
                      ),
                      const Divider(height: 32),
                      
                      // Invoice Photo
                      Text(_t('btn_take_photo'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: _imagePath == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text("Capture Invoice", style: TextStyle(color: Colors.grey)),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: _t('lbl_notes'), // Need to add this to translations if not there
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── RIGHT PANEL: ITEMS ───
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${_t('lbl_batch_items')} (${_batchItems.length})", 
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 22)),
                      ElevatedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: Text(_t('btn_add_item')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Items Table
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: _batchItems.isEmpty 
                        ? Center(child: Text(_t('msg_empty_batch'), style: const TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: _batchItems.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _batchItems[index];
                              return ListTile(
                                leading: CircleAvatar(child: Text("${index + 1}")),
                                title: Text(item.ingredientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("${_t('col_qty_received')}: ${item.quantityReceived}"),
                                trailing: SizedBox(
                                  width: 140,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "${_t('col_subtotal')}: DZD ${item.subtotal.toStringAsFixed(0)}", 
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () => setState(() => _batchItems.removeAt(index)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                  ),
                  
                  // Total Summary
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("Total Batch Cost: ", style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[700])),
                        Text("DZD ${_totalCost.toStringAsFixed(0)}", 
                          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                      ],
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
}

class _AddItemDialog extends StatefulWidget {
  final List<Ingredient> ingredients;
  final Function(StockBatchItem) onAdd;

  const _AddItemDialog({required this.ingredients, required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  Ingredient? _selected;
  final _qtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Translation logic inside dialog
    return AlertDialog(
      title: const Text("Add Ingredient to Batch"),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Ingredient>(
              value: _selected,
              decoration: const InputDecoration(labelText: 'Select Ingredient', border: OutlineInputBorder()),
              items: widget.ingredients.map((i) => DropdownMenuItem(value: i, child: Text(i.name))).toList(),
              onChanged: (val) => setState(() {
                _selected = val;
                if (val != null) _costCtrl.text = val.costPerUnit.toString();
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _qtyCtrl,
              decoration: InputDecoration(
                labelText: "Quantity Received",
                suffixText: _selected?.unit ?? '',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _costCtrl,
              decoration: const InputDecoration(
                labelText: "Cost Per Unit",
                prefixText: "DZD ",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            if (_selected == null) return;
            final qty = double.tryParse(_qtyCtrl.text) ?? 0;
            final cost = double.tryParse(_costCtrl.text) ?? 0;
            if (qty <= 0) return;

            widget.onAdd(StockBatchItem(
              batchId: 0, // Assigned on save
              ingredientId: _selected!.id!,
              ingredientName: _selected!.name,
              quantityReceived: qty,
              costPerUnit: cost,
              subtotal: qty * cost,
            ));
            Navigator.pop(context);
          },
          child: const Text("Add to Batch"),
        ),
      ],
    );
  }
}

// Global constant fallback if needed, but we should use AppSettings
const String currencySymbol = 'DZD';

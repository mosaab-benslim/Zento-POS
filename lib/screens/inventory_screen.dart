import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zento_pos/core/models/product_model.dart';
import 'package:zento_pos/core/models/ingredient_model.dart';
import 'package:zento_pos/core/providers/ingredient_provider.dart';
import 'package:zento_pos/core/providers/category_provider.dart';
import 'package:zento_pos/main.dart'; // This import is needed for scaffoldMessengerKey
import 'package:zento_pos/core/constants/translations.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/screens/admin/inventory/stock_receiving_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lang = ref.watch(languageProvider);

    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('inventory_title'), style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor: colorScheme.surface,
          bottom: TabBar(
            tabs: [
              Tab(text: t('tab_products'), icon: const Icon(Icons.shopping_bag_outlined)),
              Tab(text: t('tab_ingredients'), icon: const Icon(Icons.warehouse_outlined)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(ingredientProvider);
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _ProductInventoryTab(),
            _IngredientInventoryTab(),
          ],
        ),
      ),
    );
  }
}

class _ProductInventoryTab extends ConsumerStatefulWidget {
  const _ProductInventoryTab();

  @override
  ConsumerState<_ProductInventoryTab> createState() => _ProductInventoryTabState();
}

class _ProductInventoryTabState extends ConsumerState<_ProductInventoryTab> {
  String _searchQuery = '';
  String _filter = 'All'; 

  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await ref.read(productRepositoryProvider).getAllProducts();
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAdjustmentDialog(Product product, bool isAdding) async {
    final lang = ref.read(languageProvider);
    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    final amountCtrl = TextEditingController();
    
    final Map<String, String> reasonMap = {
      t('reason_delivery'): 'Delivery',
      t('reason_waste'): 'Waste',
      t('reason_correction'): 'Correction', 
      t('reason_theft'): 'Theft',
      t('reason_other'): 'Other',
    };
    
    final displayReasons = isAdding 
        ? [t('reason_delivery'), t('reason_correction'), t('reason_other')] 
        : [t('reason_waste'), t('reason_theft'), t('reason_correction'), t('reason_other')];
        
    String displayReason = displayReasons.first;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAdding ? t('dialog_add_stock') : t('dialog_remove_stock')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              decoration: InputDecoration(labelText: t('label_amount'), hintText: '10'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: displayReason,
              decoration: InputDecoration(
                labelText: t('label_reason'),
                border: const OutlineInputBorder(),
              ),
              items: displayReasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) => displayReason = val!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('btn_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(amountCtrl.text) ?? 0;
              if (amount > 0) {
                 String internalReason = 'Manual';
                 reasonMap.forEach((key, val) {
                   if (key == displayReason) internalReason = val;
                 });
                 
                _adjustStock(product, isAdding ? amount : -amount, internalReason);
              }
              Navigator.pop(context);
            },
            child: Text(t('btn_save')),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustStock(Product product, int amount, String reason) async {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      setState(() {
        _products[index] = product.copyWith(
          stockQuantity: product.stockQuantity + amount,
        );
      });
    }

    try {
      await ref.read(productRepositoryProvider).adjustStock(
        product.id!,
        amount,
        reason,
      );
    } catch (e) {
      if (mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error updating stock: $e')),
        );
        _loadProducts(); 
      }
    }
  }

  Future<void> _toggleTrackStock(Product product) async {
    final updatedProduct = product.copyWith(trackStock: !product.trackStock);
    await ref.read(productRepositoryProvider).saveProduct(updatedProduct);
    _loadProducts();
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_filter == 'All') return true;
      if (_filter == 'Low Stock') {
        return product.trackStock && product.stockQuantity <= product.alertLevel && product.stockQuantity > 0;
      }
      if (_filter == 'Out of Stock') {
        return product.trackStock && product.stockQuantity <= 0;
      }
      final int? catId = int.tryParse(_filter);
      if (catId != null) {
        return product.categoryId == catId;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoryProvider);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    return Row(
      children: [
        Container(
          width: 250,
          color: colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 child: Text(t('lbl_filters'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey[700], letterSpacing: 1)),
              ),
              _filterItem('All', t('filter_all'), Icons.list),
              _filterItem('Low Stock', t('filter_low'), Icons.warning_amber_rounded, Colors.orange),
              _filterItem('Out of Stock', t('filter_out'), Icons.error_outline, Colors.red),
              
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(t('lbl_categories'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey[700], letterSpacing: 1)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _filterItem(cat.id.toString(), cat.name, Icons.label_outline, null);
                  },
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: t('search_products'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(t('col_product'), style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Center(child: Text(t('col_track'), style: const TextStyle(fontWeight: FontWeight.bold)))),
                    Expanded(flex: 2, child: Center(child: Text(t('col_status'), style: const TextStyle(fontWeight: FontWeight.bold)))),
                    Expanded(flex: 2, child: Center(child: Text(t('col_stock'), style: const TextStyle(fontWeight: FontWeight.bold)))),
                    Expanded(flex: 2, child: Center(child: Text(t('col_actions'), style: const TextStyle(fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
              const Divider(),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                        ? Center(child: Text(t('no_ingredients'), style: GoogleFonts.inter(color: Colors.grey))) 
                        : ListView.separated(
                            itemCount: _filteredProducts.length,
                            separatorBuilder: (c, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              return _buildProductRow(context, product);
                            },
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterItem(String id, String label, IconData icon, [Color? color]) {
    final isSelected = _filter == id;
    return ListTile(
      leading: Icon(icon, color: isSelected ? (color ?? Theme.of(context).primaryColor) : Colors.grey),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedTileColor: Colors.blue.withOpacity(0.1),
      onTap: () => setState(() => _filter = id),
    );
  }

  Widget _buildProductRow(BuildContext context, Product product) {
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    Color statusColor = Colors.grey;
    String statusText = t('status_untracked');

    if (product.trackStock) {
      if (product.stockQuantity <= 0) {
        statusColor = Colors.red;
        statusText = t('filter_out'); 
      } else if (product.stockQuantity <= product.alertLevel) {
        statusColor = Colors.orange;
        statusText = t('filter_low'); 
      } else {
        statusColor = Colors.green;
        statusText = t('status_tracked'); 
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    image: product.imagePath != null
                        ? DecorationImage(
                            image: product.imagePath!.startsWith('http') 
                                ? NetworkImage(product.imagePath!) as ImageProvider
                                : FileImage(File(product.imagePath!)), 
                            fit: BoxFit.cover
                          )
                        : null,
                  ),
                  child: product.imagePath == null ? const Icon(Icons.fastfood, size: 24, color: Colors.grey) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("ID: ${product.id}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 1,
            child: Center(
              child: Switch(
                value: product.trackStock,
                onChanged: (val) => _toggleTrackStock(product),
                activeColor: Colors.blue,
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                product.trackStock ? '${product.stockQuantity}' : '-',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(Icons.remove, Colors.red[50]!, Colors.red[700]!, () {
                  if (product.trackStock) _showAdjustmentDialog(product, false);
                }),
                const SizedBox(width: 12),
                _buildActionButton(Icons.add, Colors.green[50]!, Colors.green[700]!, () {
                  if (product.trackStock) _showAdjustmentDialog(product, true);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withOpacity(0.3))),
        child: Icon(icon, size: 24, color: fg),
      ),
    );
  }
}

class _IngredientInventoryTab extends ConsumerStatefulWidget {
  const _IngredientInventoryTab();
  @override
  ConsumerState<_IngredientInventoryTab> createState() => _IngredientInventoryTabState();
}

class _IngredientInventoryTabState extends ConsumerState<_IngredientInventoryTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientProvider);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: t('search_ingredients'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockReceivingScreen())),
                icon: const Icon(Icons.playlist_add_check),
                label: Text(t('title_stock_receiving')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showIngredientDialog(context),
                icon: const Icon(Icons.add),
                label: Text(t('btn_new_ingredient')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(t('col_item'), style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 1, child: Center(child: Text(t('col_unit'), style: const TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(flex: 2, child: Center(child: Text(t('col_status'), style: const TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(flex: 2, child: Center(child: Text(t('col_stock'), style: const TextStyle(fontWeight: FontWeight.bold)))),
              Expanded(flex: 3, child: Center(child: Text(t('col_actions'), style: const TextStyle(fontWeight: FontWeight.bold)))), 
            ],
          ),
        ),
        const Divider(),

        Expanded(
          child: ingredientsAsync.when(
            data: (list) {
              final filtered = list.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              if (filtered.isEmpty) return Center(child: Text(t('no_ingredients')));
              
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _buildIngredientRow(context, item);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Error: $e")),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(BuildContext context, Ingredient item) {
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    final bool isLow = item.currentStock <= item.reorderLevel;
    final color = isLow ? (item.currentStock <= 0 ? Colors.red : Colors.orange) : Colors.green;
    
    String statusText = t('status_ok');
    if (item.currentStock <= 0) statusText = t('status_out');
    else if (isLow) statusText = t('status_low');

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 1, child: Center(child: Text(item.unit))),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text("${item.currentStock}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                  onPressed: () => _showIngredientDialog(context, item),
                  tooltip: "Edit",
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                  onPressed: () => _showAdjustDialog(context, item),
                  tooltip: "Adjust Stock",
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _deleteIngredient(context, item),
                  tooltip: "Delete",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteIngredient(BuildContext context, Ingredient item) async {
    final lang = ref.read(languageProvider);
    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    final usedIn = await ref.read(ingredientProvider.notifier).getIngredientUsage(item.id!);
    
    if (!mounted) return;

    if (usedIn.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('title_cannot_delete'), style: const TextStyle(color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${t('msg_ingredient_used')}:", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: usedIn.length,
                  itemBuilder: (c, i) => Text("• ${usedIn[i]}"),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Please remove it from these recipes before deleting.", style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text(t('status_ok'))
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('btn_delete') + "?"),
          content: Text("${t('msg_delete_confirm')} '${item.name}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text(t('btn_cancel'))
            ),
            TextButton(
              onPressed: () {
                ref.read(ingredientProvider.notifier).deleteIngredient(item.id!);
                Navigator.pop(ctx);
              },
              child: Text(t('btn_delete'), style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  void _showIngredientDialog(BuildContext context, [Ingredient? existing]) {
    final lang = ref.read(languageProvider);
    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    final nameCtrl = TextEditingController(text: existing?.name);
    String unit = existing?.unit ?? 'kg';
    final stockCtrl = TextEditingController(text: existing?.currentStock.toString() ?? '0');
    final reorderCtrl = TextEditingController(text: existing?.reorderLevel.toString() ?? '5');
    
    final units = ['kg', 'g', 'l', 'ml', 'pcs'];
    if (!units.contains(unit)) unit = 'kg'; 

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? t('title_add_ingredient') : t('title_edit_ingredient')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: t('label_name'))),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: unit,
              decoration: InputDecoration(labelText: t('col_unit'), border: const OutlineInputBorder()),
              items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (v) => unit = v!,
            ),
            const SizedBox(height: 16),
            if (existing == null)
              TextField(controller: stockCtrl, decoration: InputDecoration(labelText: t('label_initial_stock')), keyboardType: TextInputType.number),
            TextField(controller: reorderCtrl, decoration: InputDecoration(labelText: t('label_reorder_level')), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('btn_cancel'))),
          ElevatedButton(
            onPressed: () {
              final item = Ingredient(
                id: existing?.id,
                name: nameCtrl.text,
                unit: unit,
                currentStock: double.tryParse(stockCtrl.text) ?? 0,
                reorderLevel: double.tryParse(reorderCtrl.text) ?? 0,
              );
              ref.read(ingredientProvider.notifier).saveIngredient(item);
              Navigator.pop(context);
            },
            child: Text(t('btn_save')),
          ),
        ],
      ),
    );
  }

  void _showAdjustDialog(BuildContext context, Ingredient item) {
    final lang = ref.read(languageProvider);
    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('dialog_add_stock') + " / " + t('dialog_remove_stock')),
        content: TextField(
          controller: amountCtrl,
          decoration: const InputDecoration(labelText: "+ / -", hintText: "e.g. 10 or -5"),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t('btn_cancel'))),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              ref.read(ingredientProvider.notifier).adjustStock(item.id!, amount, "Manual Adjustment");
              Navigator.pop(context);
            },
            child: Text(t('btn_save')),
          ),
        ],
      ),
    );
  }
}

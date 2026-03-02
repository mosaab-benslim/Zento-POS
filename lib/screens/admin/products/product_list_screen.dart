import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/providers/category_provider.dart';
import 'package:zento_pos/core/providers/product_provider.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/core/models/product_model.dart';
import 'package:zento_pos/screens/admin/products/product_form_screen.dart';

import 'package:zento_pos/core/utils/currency_helper.dart';

class AdminColors {
  static const Color primary = Color(0xFF2C3E50);
  static const Color bg = Color(0xFFF4F6F8);
  static const Color accent = Color(0xFF3498DB);
}

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  int? _selectedCategoryId;

  // Translations
  String _t(WidgetRef ref, String key) {
    final lang = ref.watch(languageProvider);
    final textData = {
      'title': {AppLanguage.en: 'Products', AppLanguage.fr: 'Produits', AppLanguage.ar: 'المنتجات'},
      'add_new': {AppLanguage.en: 'Add Product', AppLanguage.fr: 'Ajouter', AppLanguage.ar: 'إضافة منتج'},
      'all': {AppLanguage.en: 'All', AppLanguage.fr: 'Tout', AppLanguage.ar: 'الكل'},
      'no_products': {AppLanguage.en: 'No products found', AppLanguage.fr: 'Aucun produit', AppLanguage.ar: 'لا توجد منتجات'},
    };
    return textData[key]?[lang] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productProvider);
    final categories = ref.watch(categoryProvider);

    // Filter Logic
    final filteredProducts = _selectedCategoryId == null
        ? products
        : products.where((p) => p.categoryId == _selectedCategoryId).toList();

    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: AppBar(
        title: Text(_t(ref, 'title'), style: const TextStyle(color: AdminColors.primary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AdminColors.primary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(_t(ref, 'add_new'), style: const TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
        },
      ),
      body: Column(
        children: [
          // 1. Category Filter Bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(null, _t(ref, 'all')),
                ...categories.map((cat) => _buildFilterChip(cat.id, cat.name)),
              ],
            ),
          ),
          
          // 2. Product Grid
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(_t(ref, 'no_products'), style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, 
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _ProductCard(product: product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int? id, String label) {
    final isSelected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AdminColors.primary,
        labelStyle: TextStyle(color: isSelected ? Colors.white : AdminColors.primary),
        backgroundColor: Colors.grey.shade100,
        onSelected: (bool selected) {
          if (selected) setState(() => _selectedCategoryId = id);
        },
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  void _confirmDelete(BuildContext context, WidgetRef ref, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Product?"),
        content: Text("Are you sure you want to delete '${product.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              ref.read(productProvider.notifier).deleteProduct(product.id);
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Area
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    color: Colors.grey.shade100,
                    image: product.imagePath != null
                        ? DecorationImage(image: FileImage(File(product.imagePath!)), fit: BoxFit.cover)
                        : null,
                  ),
                  child: product.imagePath == null
                      ? const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey))
                      : null,
                ),
                // Edit Button Overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        radius: 16,
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 16, color: AdminColors.primary),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(productToEdit: product)));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        radius: 16,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          onPressed: () => _confirmDelete(context, ref, product),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          // Info Area
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      CurrencyHelper.format(product.priceCents),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                    ),
                    Switch(
                      value: product.isEnabled,
                      activeColor: Colors.green,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                         ref.read(productProvider.notifier).toggleStatus(product.id);
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zento_pos/core/providers/category_provider.dart';
import 'package:zento_pos/core/providers/product_provider.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/core/models/product_model.dart';
import 'package:zento_pos/core/models/ingredient_model.dart';
import 'package:zento_pos/core/models/product_ingredient_model.dart';
import 'package:zento_pos/core/providers/ingredient_provider.dart';
import 'package:zento_pos/main.dart';

import 'package:zento_pos/core/constants/translations.dart';

class AdminColors {
  static const Color primary = Color(0xFF2C3E50);
  static const Color bg = Color(0xFFF4F6F8);
}

class _AddonForm {
  final TextEditingController name;
  final TextEditingController price;
  
  _AddonForm({String name = '', String price = ''}) 
    : name = TextEditingController(text: name), 
      price = TextEditingController(text: price);
  
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _RecipeDialog extends ConsumerStatefulWidget {
  final List<ProductIngredient> initialRecipe;
  final Function(List<ProductIngredient>) onSave;

  const _RecipeDialog({required this.initialRecipe, required this.onSave});

  @override
  ConsumerState<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends ConsumerState<_RecipeDialog> {
  // Map of IngredientID -> (Quantity, Unit)
  final Map<int, ({double qty, String unit})> _selections = {};

  @override
  void initState() {
    super.initState();
    // Initialize selections from current recipe
    for (var item in widget.initialRecipe) {
      _selections[item.ingredientId] = (qty: item.quantityNeeded, unit: item.ingredientUnit ?? 'kg');
    }
  }

  void _onToggle(Ingredient ing, bool? selected) {
    setState(() {
      if (selected == true) {
        // Default to ingredient's base unit, or 'g' if base is 'kg' for convenience? 
        // Let's default to the ingredient's unit first.
        _selections[ing.id!] = (qty: 1.0, unit: ing.unit); 
      } else {
        _selections.remove(ing.id);
      }
    });
  }

  void _onQuantityChanged(int ingredientId, String value) {
    final val = double.tryParse(value);
    if (val != null && _selections.containsKey(ingredientId)) {
      final current = _selections[ingredientId]!;
      _selections[ingredientId] = (qty: val, unit: current.unit);
    }
  }

  void _onUnitChanged(int ingredientId, String? newUnit) {
    if (newUnit != null && _selections.containsKey(ingredientId)) {
      final current = _selections[ingredientId]!;
      _selections[ingredientId] = (qty: current.qty, unit: newUnit);
    }
  }

  List<String> _getUnitOptions(String baseUnit) {
    // Logic: allow smaller units if base is large
    if (baseUnit == 'kg') return ['kg', 'g'];
    if (baseUnit == 'L') return ['L', 'ml'];
    return [baseUnit];
  }

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientProvider);
    final lang = ref.watch(languageProvider);
    String t(String key) => AppTranslations.data[key]?[lang] ?? key;

    return AlertDialog(
      title: Text(t('title_manage_recipe')),
      content: SizedBox(
        width: 600, 
        height: 500,
        child: Column(
          children: [
            Text(
              t('msg_recipe_instruction'),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ingredientsAsync.when(
                  data: (list) {
                     if (list.isEmpty) return const Center(child: Text("No ingredients defined."));
                     
                     final sortedList = List<Ingredient>.from(list);
                     sortedList.sort((a, b) {
                       final aSel = _selections.containsKey(a.id);
                       final bSel = _selections.containsKey(b.id);
                       if (aSel && !bSel) return -1;
                       if (!aSel && bSel) return 1;
                       return a.name.compareTo(b.name);
                     });

                     return ListView.separated(
                       itemCount: sortedList.length,
                       separatorBuilder: (c, i) => const Divider(height: 1),
                       itemBuilder: (context, index) {
                         final ing = sortedList[index];
                         final isSelected = _selections.containsKey(ing.id);
                         final selection = _selections[ing.id];
                         
                         return Container(
                           color: isSelected ? Colors.blue.withOpacity(0.05) : null,
                           child: ListTile(
                             leading: Checkbox(
                               value: isSelected,
                               onChanged: (v) => _onToggle(ing, v),
                               activeColor: AdminColors.primary,
                             ),
                             title: Text(ing.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                             subtitle: Text("Stock Unit: ${ing.unit}"),
                             trailing: isSelected 
                               ? SizedBox(
                                   width: 220, // Increased width for row
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       // Quantity Input
                                       Expanded(
                                         flex: 2,
                                         child: TextFormField(
                                           initialValue: selection!.qty.toString(),
                                           keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                           decoration: const InputDecoration(
                                              isDense: true, 
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                              border: OutlineInputBorder(),
                                              labelText: 'Qty'
                                            ),
                                           onChanged: (v) => _onQuantityChanged(ing.id!, v),
                                         ),
                                       ),
                                       const SizedBox(width: 8),
                                       // Unit Dropdown
                                       Expanded(
                                         flex: 2,
                                         child: DropdownButtonFormField<String>(
                                           value: selection.unit,
                                           isExpanded: true,
                                           decoration: const InputDecoration(
                                             isDense: true,
                                             contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                             border: OutlineInputBorder(),
                                           ),
                                           items: _getUnitOptions(ing.unit).map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                                           onChanged: (v) => _onUnitChanged(ing.id!, v),
                                         ),
                                       ),
                                     ],
                                   ),
                                 )
                               : null,
                             onTap: () => _onToggle(ing, !isSelected),
                           ),
                         );
                       },
                     );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text("Error: $e")),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t('btn_cancel'))),
        ElevatedButton(
          onPressed: () {
            final List<ProductIngredient> finalRecipe = [];
            _selections.forEach((id, val) {
              final ing = ref.read(ingredientProvider).value?.firstWhere((i) => i.id == id);
              if (ing != null) {
                finalRecipe.add(ProductIngredient(
                  productId: 0, 
                  ingredientId: id,
                  quantityNeeded: val.qty,
                  ingredientName: ing.name,
                  ingredientUnit: val.unit,
                ));
              }
            });
            widget.onSave(finalRecipe);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(t('btn_save')), // Was "Save Recipe", but 'Save' is generic enough or add 'btn_save_recipe'
        ),
      ],
    );
  }
}

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? productToEdit;

  const ProductFormScreen({super.key, this.productToEdit});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  
  // State
  int? _selectedCategoryId;
  String? _imagePath;
  bool _isEnabled = true;
  
  // Addons State
  final List<_AddonForm> _addonForms = [];

  // Recipe State
  List<ProductIngredient> _recipe = [];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(text: p?.priceCents.toString() ?? '');
    _costController = TextEditingController(text: p?.costCents.toString() ?? '');
    _selectedCategoryId = p?.categoryId;
    _imagePath = p?.imagePath;
    _isEnabled = p?.isEnabled ?? true;
    
    // Initialize Addons
    if (p != null && p.addons.isNotEmpty) {
      for (var addon in p.addons) {
        _addonForms.add(_AddonForm(name: addon.name, price: addon.priceCents.toString()));
      }
    }

    // Load Recipe if editing
    if (p != null) {
      _loadRecipe(p.id!);
    }
  }

  Future<void> _loadRecipe(int productId) async {
    final recipe = await ref.read(ingredientProvider.notifier).getRecipe(productId);
    setState(() => _recipe = recipe);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    for (var f in _addonForms) f.dispose();
    super.dispose();
  }

  // ---------------- TRANSLATIONS ----------------
  String _t(String key) {
    final lang = ref.watch(languageProvider);
    // Use centralised translations
    return AppTranslations.data[key]?[lang] ?? key;
  }

  // ---------------- IMAGE LOGIC ----------------
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _imagePath = pickedFile.path);
    }
  }

  void _showImageSourceActionSheet() {
    if (Platform.isWindows) {
      _pickImage(ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.photo), title: const Text('Gallery'), onTap: () { _pickImage(ImageSource.gallery); Navigator.pop(context); }),
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Camera'), onTap: () { _pickImage(ImageSource.camera); Navigator.pop(context); }),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('btn_delete') + "?"),
        content: Text(_t('msg_delete_product')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('btn_cancel'))),
          TextButton(
            onPressed: () async {
              final res = await ref.read(productProvider.notifier).deleteProduct(widget.productToEdit!.id!);
              if (!mounted) return;
              if (res.isSuccess) {
                Navigator.pop(ctx); // Dialog
                Navigator.pop(context); // Form
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error!)));
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t('btn_delete')),
          ),
        ],
      ),
    );
  }

  // ---------------- SUBMIT LOGIC ----------------
  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      // Parse as double first to handle user input like "100.0", then round to int
      final int price = (double.tryParse(_priceController.text) ?? 0).round();
      final int cost = (double.tryParse(_costController.text) ?? 0).round();

      // Collect Addons
      final List<ProductAddon> addons = _addonForms.map((f) {
        return ProductAddon(
          name: f.name.text,
          priceCents: (double.tryParse(f.price.text) ?? 0).round(),
        );
      }).where((a) => a.name.isNotEmpty).toList();

      final product = Product(
        id: widget.productToEdit?.id,
        name: _nameController.text,
        categoryId: _selectedCategoryId!,
        priceCents: price,
        costCents: cost,
        imagePath: _imagePath,
        isEnabled: _isEnabled,
        addons: addons,
      );

      // SAVE via Provider
      final notifier = ref.read(productProvider.notifier);
      final result = widget.productToEdit == null
          ? await notifier.addProduct(product)
          : await notifier.editProduct(product);

      if (!mounted) return;

      if (result.isSuccess) {
         // SAVE Recipe after product is created/updated
         final pid = result.value; 
         if (pid != null) {
           await ref.read(ingredientProvider.notifier).saveRecipe(pid, _recipe);
         }

         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("${_t('btn_save')} ${widget.productToEdit == null ? _t('msg_success') : _t('msg_updated')}"), backgroundColor: Colors.green)
         );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("${_t('msg_error')}: ${result.error}"), backgroundColor: Colors.red)
         );
      }
    }
  }

  void _addAddon() {
    setState(() {
      _addonForms.add(_AddonForm());
    });
  }

  void _removeAddon(int index) {
    setState(() {
      _addonForms[index].dispose();
      _addonForms.removeAt(index);
    });
  }

  // Helper methods

  void _showRecipeDialog() {
    showDialog(
      context: context,
      builder: (context) => _RecipeDialog(
        initialRecipe: _recipe,
        onSave: (newRecipe) => setState(() => _recipe = newRecipe),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final isEditing = widget.productToEdit != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? _t('title_edit_product') : _t('title_add_product'), style: const TextStyle(color: AdminColors.primary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AdminColors.primary),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Image Picker (Centered)
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceActionSheet,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: AdminColors.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      image: _imagePath != null
                          ? DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _imagePath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text("Add Image", style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 2. Basic Info Section
              Text(_t('section_basic'), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Divider(),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _t('lbl_name'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                validator: (v) => v!.isEmpty ? _t('err_req') : null,
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: _t('lbl_category'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat.id,
                    child: Text(cat.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                validator: (val) => val == null ? _t('err_cat') : null,
              ),

              const SizedBox(height: 32),

              // 3. Pricing Section
              Text(_t('section_pricing'), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Divider(),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _t('lbl_price'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.money, color: Colors.green),
                      ),
                      validator: (v) => v!.isEmpty ? _t('err_req') : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _t('lbl_cost'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.money_off, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              // 4. Addons Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_t('section_addons'), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  TextButton.icon(
                    onPressed: _addAddon,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(_t('btn_add_addon')),
                  ),
                ],
              ),
                  const Divider(),
              if (_addonForms.isEmpty)
                 Padding(
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   child: Text("No addons added.", style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                 )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _addonForms.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _addonForms[index].name,
                            decoration: InputDecoration(
                              labelText: _t('lbl_addon_name'),
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _addonForms[index].price,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: _t('lbl_addon_price'),
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeAddon(index),
                        ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 32),

              // 4.5 Recipe Section
              Text(_t('section_recipe'), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const Divider(),
              const SizedBox(height: 8),
              if (_recipe.isEmpty)
                Text("No ingredients linked. This product will use standard stock tracking.", style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic, fontSize: 13))
              else
                Wrap(
                  spacing: 8,
                  children: _recipe.map((ri) => Chip(
                    label: Text("${ri.ingredientName} (${ri.quantityNeeded}${ri.ingredientUnit})", style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _recipe.remove(ri)),
                  )).toList(),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showRecipeDialog,
                  icon: const Icon(Icons.restaurant_menu),
                  label: Text(_t('btn_manage_recipe')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AdminColors.primary),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const SizedBox(height: 32),

              // 5. Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AdminColors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _isEnabled ? _t('lbl_enabled') : (_t('lbl_enabled') == 'Available for sale' ? 'Hidden from menu' : (_t('lbl_enabled') == 'Disponible à la vente' ? 'Masqué' : 'غير متاح للتوصيل')), 
                    style: const TextStyle(fontWeight: FontWeight.w600)
                  ),
                  value: _isEnabled,
                  activeColor: Colors.green,
                  onChanged: (val) => setState(() => _isEnabled = val),
                ),
              ),

              const SizedBox(height: 40),

              // 6. Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    _t('btn_save'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

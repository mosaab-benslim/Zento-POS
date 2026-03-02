import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/providers/category_provider.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/core/models/category_model.dart';

class AdminColors {
  static const Color primary = Color(0xFF2C3E50);
  static const Color bg = Color(0xFFF4F6F8);
}

class CategoryFormScreen extends ConsumerStatefulWidget {
  final Category? categoryToEdit;

  const CategoryFormScreen({super.key, this.categoryToEdit});

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late int _selectedColor;
  String? _imagePath;
  bool _isEnabled = true;
  final ImagePicker _picker = ImagePicker();

  // Predefined palette for POS categories (Visually distinct colors)
  final List<int> _colorPalette = [
    0xFFE74C3C, // Red
    0xFFE67E22, // Orange
    0xFFF1C40F, // Yellow
    0xFF2ECC71, // Green
    0xFF1ABC9C, // Teal
    0xFF3498DB, // Blue
    0xFF9B59B6, // Purple
    0xFF34495E, // Navy
    0xFF95A5A6, // Grey
    0xFFECF0F1, // White/Light
  ];

  @override
  void initState() {
    super.initState();
    // Initialize data if editing, or default if new
    _nameController = TextEditingController(text: widget.categoryToEdit?.name ?? '');
    _selectedColor = widget.categoryToEdit?.colorValue ?? _colorPalette[0];
    _imagePath = widget.categoryToEdit?.imagePath;
    _isEnabled = widget.categoryToEdit?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Translations
  static final Map<String, Map<AppLanguage, String>> _text = {
    'title_add': {AppLanguage.en: 'New Category', AppLanguage.fr: 'Nouvelle Catégorie', AppLanguage.ar: 'قسم جديد'},
    'title_edit': {AppLanguage.en: 'Edit Category', AppLanguage.fr: 'Modifier Catégorie', AppLanguage.ar: 'تعديل القسم'},
    'label_name': {AppLanguage.en: 'Category Name', AppLanguage.fr: 'Nom de Catégorie', AppLanguage.ar: 'اسم القسم'},
    'label_color': {AppLanguage.en: 'Color Code', AppLanguage.fr: 'Code Couleur', AppLanguage.ar: 'رمز اللون'},
    'label_enabled': {AppLanguage.en: 'Enabled', AppLanguage.fr: 'Activé', AppLanguage.ar: 'مفعل'},
    'btn_save': {AppLanguage.en: 'Save Category', AppLanguage.fr: 'Enregistrer', AppLanguage.ar: 'حفظ'},
    'err_required': {AppLanguage.en: 'Field required', AppLanguage.fr: 'Champs requis', AppLanguage.ar: 'مطلوب'},
    'label_image': {AppLanguage.en: 'Category Image', AppLanguage.fr: 'Image de Catégorie', AppLanguage.ar: 'صورة القسم'},
    'source_gallery': {AppLanguage.en: 'Gallery', AppLanguage.fr: 'Galerie', AppLanguage.ar: 'المعرض'},
    'source_camera': {AppLanguage.en: 'Camera', AppLanguage.fr: 'الكاميرا', AppLanguage.ar: 'الكاميرا'},
  };

  String _t(String key) {
    final lang = ref.watch(languageProvider);
    return _text[key]?[lang] ?? key;
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (widget.categoryToEdit == null) {
        // Create Mode
        ref.read(categoryProvider.notifier).addCategory(
              _nameController.text,
              _selectedColor,
              imagePath: _imagePath,
            );
      } else {
        // Edit Mode
        ref.read(categoryProvider.notifier).editCategory(
              widget.categoryToEdit!.id!,
              _nameController.text,
              _selectedColor,
              imagePath: _imagePath,
            );
        // Ensure status is up to date if it was changed in form
        if (widget.categoryToEdit!.isEnabled != _isEnabled) {
             ref.read(categoryProvider.notifier).toggleStatus(widget.categoryToEdit!.id!);
        }
      }
      Navigator.pop(context);
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(_t('source_gallery')),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: Text(_t('source_camera')),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Category?"),
        content: const Text("This will remove the category and all associated products may become unorganized."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              ref.read(categoryProvider.notifier).deleteCategory(widget.categoryToEdit!.id!);
              Navigator.pop(ctx); // Dialog
              Navigator.pop(context); // Form Screen
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.categoryToEdit != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEditing ? _t('title_edit') : _t('title_add'),
          style: const TextStyle(color: AdminColors.primary, fontWeight: FontWeight.bold),
        ),
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
              // 0. Image Picker
              Center(
                child: GestureDetector(
                  onTap: () => _showImageSourceActionSheet(context),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AdminColors.bg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _imagePath != null
                        ? Image.file(File(_imagePath!), fit: BoxFit.cover)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(_t('label_image'), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 1. Name Input
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _t('label_name'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: AdminColors.bg,
                ),
                validator: (value) => value!.isEmpty ? _t('err_required') : null,
              ),
              const SizedBox(height: 24),

              // 2. Enable Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEnabled ? _t('label_enabled') : (_t('label_enabled') == 'Enabled' ? 'Disabled' : (_t('label_enabled') == 'Activé' ? 'Désactivé' : 'غير مفعل')), 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AdminColors.primary)
                  ),
                  Switch(
                    value: _isEnabled,
                    onChanged: (val) => setState(() => _isEnabled = val),
                    activeColor: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. Color Selection
              Text(_t('label_color'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AdminColors.primary)),
              const SizedBox(height: 12),
              
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _colorPalette.map((colorVal) {
                  final isSelected = _selectedColor == colorVal;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorVal),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: isSelected 
                            ? Border.all(color: AdminColors.primary, width: 3) 
                            : Border.all(color: Colors.grey.shade300, width: 1),
                        boxShadow: isSelected 
                            ? [BoxShadow(color: Color(colorVal).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] 
                            : [],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),

              // 4. Save Button
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

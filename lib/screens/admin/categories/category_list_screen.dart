import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/providers/category_provider.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/core/models/category_model.dart';
import 'package:zento_pos/screens/admin/categories/category_form_screen.dart';

// Reuse your AdminColors from dashboard
class AdminColors {
  static const Color primary = Color(0xFF2C3E50);
  static const Color bg = Color(0xFFF4F6F8);
}

class CategoryListScreen extends ConsumerWidget {
  const CategoryListScreen({super.key});

  static final Map<String, Map<AppLanguage, String>> _text = {
    'title': {AppLanguage.en: 'Categories', AppLanguage.fr: 'Catégories', AppLanguage.ar: 'الأقسام'},
    'add_new': {AppLanguage.en: 'Add Category', AppLanguage.fr: 'Ajouter', AppLanguage.ar: 'إضافة قسم'},
    'empty': {AppLanguage.en: 'No categories found', AppLanguage.fr: 'Aucune catégorie', AppLanguage.ar: 'لا توجد أقسام'},
    'delete_confirm': {AppLanguage.en: 'Delete this category?', AppLanguage.fr: 'Supprimer?', AppLanguage.ar: 'حذف القسم؟'},
    'cancel': {AppLanguage.en: 'Cancel', AppLanguage.fr: 'Annuler', AppLanguage.ar: 'إلغاء'},
    'delete': {AppLanguage.en: 'Delete', AppLanguage.fr: 'Supprimer', AppLanguage.ar: 'حذف'},
  };

  String _t(WidgetRef ref, String key) {
    final lang = ref.watch(languageProvider);
    return _text[key]?[lang] ?? key;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);

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
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryFormScreen()));
        },
      ),
      body: categories.isEmpty
          ? Center(child: Text(_t(ref, 'empty'), style: TextStyle(color: Colors.grey.shade500)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CategoryFormScreen(categoryToEdit: category)),
                      );
                    },
                    onLongPress: () {
                      if (category.id != null) {
                        _confirmDelete(context, ref, category.id!);
                      }
                    },
                    // Image thumbnail
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: category.imagePath == null ? category.color : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                        image: category.imagePath != null
                            ? DecorationImage(
                                image: FileImage(File(category.imagePath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: category.imagePath == null
                          ? Center(
                              child: Text(
                                category.name.isNotEmpty ? category.name[0].toUpperCase() : '',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AdminColors.primary),
                    ),
                    subtitle: Text(
                      category.isEnabled 
                        ? (ref.read(languageProvider) == AppLanguage.en ? "Active" : (ref.read(languageProvider) == AppLanguage.fr ? "Actif" : "مفعل")) 
                        : (ref.read(languageProvider) == AppLanguage.en ? "Disabled" : (ref.read(languageProvider) == AppLanguage.fr ? "Désactivé" : "معطل")),
                      style: TextStyle(
                        color: category.isEnabled ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: category.isEnabled,
                          activeColor: Colors.green,
                          onChanged: (val) {
                            if (category.id != null) {
                              ref.read(categoryProvider.notifier).toggleStatus(category.id!);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () {
                            if (category.id != null) {
                              _confirmDelete(context, ref, category.id!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(ref, 'delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t(ref, 'cancel')),
          ),
          TextButton(
            onPressed: () {
              ref.read(categoryProvider.notifier).deleteCategory(id);
              Navigator.pop(ctx);
            },
            child: Text(_t(ref, 'delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

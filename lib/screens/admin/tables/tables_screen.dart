import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart'; // For tableRepositoryProvider
import '../../../../core/models/table_model.dart';
import '../../../../core/providers/language_provider.dart'; // ✅ Added
import '../../../../enums/app_language.dart'; // ✅ Added

class TablesScreen extends ConsumerStatefulWidget {
  const TablesScreen({super.key});

  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  final _nameController = TextEditingController();
  List<TableModel> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    final repo = ref.read(tableRepositoryProvider);
    final tables = await repo.getAllTables();
    setState(() {
      _tables = tables;
      _isLoading = false;
    });
  }

  Future<void> _addTable(String name) async {
    if (name.trim().isEmpty) return;
    final repo = ref.read(tableRepositoryProvider);
    await repo.addTable(TableModel(name: name));
    _nameController.clear();
    await _loadTables();
  }

  Future<void> _deleteTable(int id) async {
    final repo = ref.read(tableRepositoryProvider);
    await repo.deleteTable(id);
    await _loadTables();
  }

  // ───────────────── TRANSLATIONS ─────────────────
  String _t(String key) {
    final lang = ref.read(languageProvider);
    final text = {
      'title': {AppLanguage.en: 'Manage Tables', AppLanguage.fr: 'Gérer les Tables', AppLanguage.ar: 'إدارة الطاولات'},
      'no_tables': {AppLanguage.en: 'No tables yet.', AppLanguage.fr: 'Aucune table.', AppLanguage.ar: 'لا توجد طاولات.'},
      'hint_add': {AppLanguage.en: 'Tap the + button to add one.', AppLanguage.fr: 'Appuyez sur + pour ajouter.', AppLanguage.ar: 'اضغط على + لإضافة طاولة.'},
      'dialog_add_title': {AppLanguage.en: 'Add New Table', AppLanguage.fr: 'Nouvelle Table', AppLanguage.ar: 'طاولة جديدة'},
      'input_label': {AppLanguage.en: 'Table Name', AppLanguage.fr: 'Nom de la Table', AppLanguage.ar: 'اسم الطاولة'},
      'btn_cancel': {AppLanguage.en: 'Cancel', AppLanguage.fr: 'Annuler', AppLanguage.ar: 'إلغاء'},
      'btn_add': {AppLanguage.en: 'Add', AppLanguage.fr: 'Ajouter', AppLanguage.ar: 'إضافة'},
      'dialog_del_title': {AppLanguage.en: 'Delete Table?', AppLanguage.fr: 'Supprimer?', AppLanguage.ar: 'حذف؟'},
      'dialog_del_msg': {AppLanguage.en: 'Delete ', AppLanguage.fr: 'Supprimer ', AppLanguage.ar: 'حذف '},
      'btn_delete': {AppLanguage.en: 'Delete', AppLanguage.fr: 'Supprimer', AppLanguage.ar: 'حذف'},
    };
    return text[key]?[lang] ?? key;
  }

  void _showAddTableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('dialog_add_title')),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: _t('input_label'),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('btn_cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              _addTable(_nameController.text);
              Navigator.pop(context);
            },
            child: Text(_t('btn_add')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider); // ✅ Trigger rebuild
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('title')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tables.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.table_restaurant, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _t('no_tables'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(_t('hint_add')),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 columns for tablets/desktop
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _tables.length,
                  itemBuilder: (context, index) {
                    final table = _tables[index];
                    return Card(
                      elevation: 4,
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              table.name,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _showDeleteConfirm(table),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTableDialog,
        icon: const Icon(Icons.add),
        label: Text(_t('btn_add')),
      ),
    );
  }

  void _showDeleteConfirm(TableModel table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('dialog_del_title')),
        content: Text("${_t('dialog_del_msg')}'${table.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('btn_cancel'))),
          TextButton(
            onPressed: () {
              if (table.id != null) _deleteTable(table.id!);
              Navigator.pop(context);
            },
            child: Text(_t('btn_delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

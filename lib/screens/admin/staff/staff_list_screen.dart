import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/database/user_dao.dart';
import 'package:zento_pos/core/models/user_model.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/main.dart'; // ✅ Added for scaffoldMessengerKey

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final _userDao = UserDao();
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await _userDao.getAllUsers();
    if (mounted) {
      setState(() {
        _users = users;
        _isLoading = false;
      });
    }
  }

  String _t(String key) {
    final lang = ref.watch(languageProvider);
    final text = {
      'title': {AppLanguage.en: 'Staff Management', AppLanguage.fr: 'Gestion du Personnel', AppLanguage.ar: 'إدارة الموظفين'},
      'edit_pin': {AppLanguage.en: 'Update PIN', AppLanguage.fr: 'Changer le PIN', AppLanguage.ar: 'تحديث الرقم السري'},
      'new_pin': {AppLanguage.en: 'New PIN', AppLanguage.fr: 'Nouveau PIN', AppLanguage.ar: 'رقم سري جديد'},
      'confirm_pin': {AppLanguage.en: 'Confirm PIN', AppLanguage.fr: 'Confirmer PIN', AppLanguage.ar: 'تأكيد الرقم السري'},
      'pin_error': {AppLanguage.en: 'PINs do not match', AppLanguage.fr: 'Les PIN ne correspondent pas', AppLanguage.ar: 'الأرقام غير متطابقة'},
      'pin_length': {AppLanguage.en: 'PIN must be 4-8 digits', AppLanguage.fr: 'Le PIN doit avoir 4 à 8 chiffres', AppLanguage.ar: 'يجب أن يكون بين 4-8 أرقام'},
      'success': {AppLanguage.en: 'PIN updated successfully', AppLanguage.fr: 'PIN mis à jour avec succès', AppLanguage.ar: 'تم تحديث الرقم السري بنجاح'},
      'cancel': {AppLanguage.en: 'Cancel', AppLanguage.fr: 'Annuler', AppLanguage.ar: 'إلغاء'},
      'save': {AppLanguage.en: 'Save', AppLanguage.fr: 'Enregistrer', AppLanguage.ar: 'حفظ'},
    };
    return text[key]?[lang] ?? key;
  }

  void _showUpdatePinDialog(UserModel user) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_t('edit_pin')} - ${user.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinController,
                decoration: InputDecoration(labelText: _t('new_pin')),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (val) {
                  if (val == null || val.length < 4 || val.length > 8) return _t('pin_length');
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmController,
                decoration: InputDecoration(labelText: _t('confirm_pin')),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (val) {
                  if (val != pinController.text) return _t('pin_error');
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final success = await _userDao.updatePin(user.id!, pinController.text);
                if (mounted) {
                  Navigator.pop(context);
                  if (success) {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      SnackBar(content: Text(_t('success')), backgroundColor: Colors.green),
                    );
                  }
                }
              }
            },
            child: Text(_t('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('title'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.role == UserRole.admin 
                          ? Colors.red.shade100 
                          : (user.role == UserRole.manager ? Colors.orange.shade100 : Colors.blue.shade100),
                      child: Icon(
                        user.role == UserRole.admin 
                            ? Icons.security 
                            : (user.role == UserRole.manager ? Icons.manage_accounts : Icons.person),
                        color: user.role == UserRole.admin 
                            ? Colors.red 
                            : (user.role == UserRole.manager ? Colors.orange : Colors.blue),
                      ),
                    ),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(user.role.name.toUpperCase()),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _showUpdatePinDialog(user),
                      icon: const Icon(Icons.lock_reset, size: 18),
                      label: Text(_t('edit_pin')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C3E50),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

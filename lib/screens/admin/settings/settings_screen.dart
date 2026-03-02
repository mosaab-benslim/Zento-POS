import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zento_pos/core/models/app_settings_model.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/core/repositories/app_settings_repository.dart';
import 'package:zento_pos/core/utils/receipt_helper.dart';
import 'package:zento_pos/core/services/printer_service.dart';
import 'package:zento_pos/core/providers/printer_provider.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:zento_pos/core/models/order_model.dart';
import 'package:zento_pos/core/models/order_item_model.dart';
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/main.dart';
import 'package:zento_pos/core/services/backup_service.dart'; // ✅ Added
import 'package:file_picker/file_picker.dart'; // ✅ Added
import 'package:zento_pos/core/providers/auth_provider.dart'; // For restart if needed

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _footerController;
  late TextEditingController _storeNameController;
  String? _logoPath;
  bool _autoPrint = false;
  bool _enableTables = false;
  String _currency = 'DZD';
  bool _isLoading = true;
  String? _selectedPrinterName; 
  bool _enableAutoBackup = false;
  String? _autoBackupPath;
  bool _enableKitchenPrinter = false;
  String? _kitchenPrinterAddress;
  String? _kitchenPrinterType = 'usb';
  bool _autoPrintKot = false;

  @override
  void initState() {
    super.initState();
    _footerController = TextEditingController();
    _storeNameController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(appSettingsRepositoryProvider);
    final settings = await repo.getSettings() ?? const AppSettings();
    setState(() {
      _footerController.text = settings.receiptFooter;
      _storeNameController.text = settings.storeName;
      _enableTables = settings.enableTables;
      _logoPath = settings.receiptLogoPath;
      _autoPrint = settings.autoPrintReceipt;
      _currency = (settings.currency == 'DZD') ? 'DZD' : 'DZD'; 
      _selectedPrinterName = settings.printerAddress;
      _enableAutoBackup = settings.enableAutoBackup;
      _autoBackupPath = settings.autoBackupPath;
      _enableKitchenPrinter = settings.enableKitchenPrinter;
      _kitchenPrinterAddress = settings.kitchenPrinterAddress;
      _kitchenPrinterType = settings.kitchenPrinterType;
      _autoPrintKot = settings.autoPrintKot;
      _isLoading = false;
    });

    // Notify global provider of the saved name
    ref.read(printerProvider.notifier).setPrinterName(settings.printerAddress);
  }

  @override
  void dispose() {
    _footerController.dispose();
    _storeNameController.dispose();
    super.dispose();
  }

  String _t(String key) {
    final lang = ref.read(languageProvider);
    final text = {
      'title': {AppLanguage.en: 'Settings', AppLanguage.fr: 'Paramètres', AppLanguage.ar: 'الإعدادات'},
      'sec_receipt': {AppLanguage.en: 'Receipt & Printing', AppLanguage.fr: 'Reçu et Impression', AppLanguage.ar: 'الإيصال والطباعة'},
      'sec_general': {AppLanguage.en: 'General', AppLanguage.fr: 'Général', AppLanguage.ar: 'عام'},
      'lbl_store_name': {AppLanguage.en: 'Store Name', AppLanguage.fr: 'Nom du Magasin', AppLanguage.ar: 'اسم المطعم'},
      'lbl_currency': {AppLanguage.en: 'Currency', AppLanguage.fr: 'Devise', AppLanguage.ar: 'العملة'},
      'lbl_logo': {AppLanguage.en: 'Receipt Logo', AppLanguage.fr: 'Logo du Reçu', AppLanguage.ar: 'شعار الإيصال'},
      'lbl_footer': {AppLanguage.en: 'Receipt Footer', AppLanguage.fr: 'Pied de Reçu', AppLanguage.ar: 'تذييل الإيصال'},
      'lbl_autoprint': {AppLanguage.en: 'Auto-Print Receipt', AppLanguage.fr: 'Impression Auto', AppLanguage.ar: 'طباعة تلقائية'},
      'btn_save': {AppLanguage.en: 'Save Settings', AppLanguage.fr: 'Enregistrer', AppLanguage.ar: 'حفظ الإعدادات'},
      'btn_test': {AppLanguage.en: 'Preview & Test Receipt', AppLanguage.fr: 'Aperçu et Test', AppLanguage.ar: 'معاينة واختبار الإيصال'},
      'msg_success': {AppLanguage.en: 'Settings saved!', AppLanguage.fr: 'Paramètres enregistrés!', AppLanguage.ar: 'تم حفظ الإعدادات!'},
      // Table Management Translations
      'lbl_enable_tables': {AppLanguage.en: 'Enable Table Management', AppLanguage.fr: 'Gestion des Tables', AppLanguage.ar: 'تفعيل إدارة الطاولات'},
      'sub_enable_tables': {AppLanguage.en: 'Use tables for orders (Dine In)', AppLanguage.fr: 'Utiliser les tables pour les commandes', AppLanguage.ar: 'استخدام الطاولات للطلبات المحلي'},
      // Backup & Restore
      'sec_maintenance': {AppLanguage.en: 'Maintenance & Data Safety', AppLanguage.fr: 'Maintenance et Sécurité', AppLanguage.ar: 'الصيانة وأمن البيانات'},
      'lbl_backup': {AppLanguage.en: 'Backup Database', AppLanguage.fr: 'Sauvegarder la Base', AppLanguage.ar: 'نسخ احتياطي للقاعدة'},
      'lbl_restore': {AppLanguage.en: 'Restore Database', AppLanguage.fr: 'Restaurer la Base', AppLanguage.ar: 'استعادة قاعدة البيانات'},
      'sub_backup': {AppLanguage.en: 'Export your data to a safe file', AppLanguage.fr: 'Exporter vos données', AppLanguage.ar: 'تصدير بياناتك إلى ملف آمن'},
      'sub_restore': {AppLanguage.en: 'OVERWRITE current data with a backup', AppLanguage.fr: 'ÉCRASER les données actuelles', AppLanguage.ar: 'استبدال البيانات الحالية بنسخة احتياطية'},
      'msg_backup_success': {AppLanguage.en: 'Backup saved to: ', AppLanguage.fr: 'Sauvegarde enregistrée: ', AppLanguage.ar: 'تم حفظ النسخة في: '},
      'msg_restore_success': {AppLanguage.en: 'Database restored! Please restart the app.', AppLanguage.fr: 'Base restaurée! Veuillez redémarrer.', AppLanguage.ar: 'تمت استعادة البيانات! يرجى إعادة تشغيل التطبيق.'},
      'msg_restore_confirm': {AppLanguage.en: 'Are you sure? This will delete all current data and replace it with the backup.', AppLanguage.fr: 'Êtes-vous sûr? Cela supprimera toutes les données actuelles.', AppLanguage.ar: 'هل أنت متأكد؟ سيؤدي هذا إلى حذف كل البيانات الحالية واستبدالها بالنسخة الاحتياطية.'},
      // Pro Backups
      'lbl_share': {AppLanguage.en: 'Share via Email/Apps', AppLanguage.fr: 'Partager (Email/Apps)', AppLanguage.ar: 'مشاركة عبر البريد/التطبيقات'},
      'sub_share': {AppLanguage.en: 'Send backup to your email or cloud', AppLanguage.fr: 'Envoyer vers email/cloud', AppLanguage.ar: 'إرسال النسخة للبريد أو السحابة'},
      'lbl_auto_backup': {AppLanguage.en: 'Automatic Cloud Backup', AppLanguage.fr: 'Sauvegarde Auto Cloud', AppLanguage.ar: 'نسخ احتياطي تلقائي سحابي'},
      'sub_auto_backup': {AppLanguage.en: 'Sync to OneDrive/Google Drive folder', AppLanguage.fr: 'Sync vers dossier OneDrive/Drive', AppLanguage.ar: 'مزامنة مع مجلد ون درايف/درايف'},
      'lbl_pick_folder': {AppLanguage.en: 'Set Cloud Sync Folder', AppLanguage.fr: 'Définir le dossier Cloud', AppLanguage.ar: 'تحديد مجلد المزامنة'},
      'msg_auto_backup_off': {AppLanguage.en: 'Select a folder to enable auto-backup', AppLanguage.fr: 'Sélectionnez un dossier', AppLanguage.ar: 'اختر مجلداً لتفعيل النسخ التلقائي'},
      // KOT & Kitchen Printer
      'sec_kitchen': {AppLanguage.en: 'Kitchen Order System', AppLanguage.fr: 'Système Production Cuisine', AppLanguage.ar: 'نظام طلبات المطبخ'},
      'lbl_enable_kot': {AppLanguage.en: 'Enable Kitchen Printing', AppLanguage.fr: 'Activer Impression Cuisine', AppLanguage.ar: 'تفعيل طباعة المطبخ'},
      'sub_enable_kot': {AppLanguage.en: 'Send separate tickets to the kitchen', AppLanguage.fr: 'Envoyer des bons séparés à la cuisine', AppLanguage.ar: 'إرسال تذاكر منفصلة للمطبخ'},
      'lbl_kitchen_ip': {AppLanguage.en: 'Kitchen Printer (IP / Port)', AppLanguage.fr: 'Imprimante Cuisine (IP)', AppLanguage.ar: 'طابعة المطبخ (IP)'},
      'lbl_kot_autoprint': {AppLanguage.en: 'Auto-Print KOT on Checkout', AppLanguage.fr: 'Impression Auto KOT', AppLanguage.ar: 'طباعة تلقائية لطلب المطبخ'},
      'lbl_printer_type': {AppLanguage.en: 'Connection Type', AppLanguage.fr: 'Type de Connexion', AppLanguage.ar: 'نوع الاتصال'},
    };
    return text[key]?[lang] ?? key;
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _logoPath = pickedFile.path);
    }
  }

  Future<void> _save() async {
    final repo = ref.read(appSettingsRepositoryProvider);
    final current = await repo.getSettings() ?? const AppSettings();
    
    final updated = current.copyWith(
      receiptFooter: _footerController.text,
      storeName: _storeNameController.text,
      receiptLogoPath: _logoPath,
      autoPrintReceipt: _autoPrint,
      currency: _currency,
      enableTables: _enableTables,
      printerAddress: _selectedPrinterName,
      enableAutoBackup: _enableAutoBackup,
      autoBackupPath: _autoBackupPath,
      enableKitchenPrinter: _enableKitchenPrinter,
      kitchenPrinterAddress: _kitchenPrinterAddress,
      kitchenPrinterType: _kitchenPrinterType,
      autoPrintKot: _autoPrintKot,
    );

    await repo.updateSettings(updated);
    
    // Sync with global provider
    ref.read(printerProvider.notifier).setPrinterName(_selectedPrinterName);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('msg_success')), backgroundColor: Colors.green),
    );
  }

  void _testPrint() {
    // 1. Create a dummy order for testing
    final dummyOrder = OrderModel(
      id: 9999,
      orderType: OrderType.dineIn,
      totalCents: 5000,
      createdAt: DateTime.now(),
      cashierId: 1,
      queueNumber: 106,
    );

    final dummyItems = [
      const OrderItem(orderId: 9999, productId: 1, productName: "Test Burger", quantity: 2, priceCents: 2000),
      const OrderItem(orderId: 9999, productId: 2, productName: "Test Soda", quantity: 1, priceCents: 1000),
    ];

    // 2. Use the currently entered settings (even if not saved yet)
    final testSettings = AppSettings(
      storeName: _storeNameController.text,
      currency: _currency,
      receiptFooter: _footerController.text,
      receiptLogoPath: _logoPath,
      autoPrintReceipt: _autoPrint,
    );

    // 3. Show preview
    ReceiptHelper.showReceiptPreview(
      context: context,
      order: dummyOrder,
      items: dummyItems,
      settings: testSettings,
      lang: ref.read(languageProvider),
    );

    // Also show kitchen for testing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ReceiptHelper.showReceiptPreview(
          context: context,
          order: dummyOrder,
          items: dummyItems,
          settings: testSettings,
          lang: ref.read(languageProvider),
          isKitchen: true,
        );
      }
    });
  }

  Future<void> _handleBackup() async {
    try {
      final path = await BackupService.backupDatabase();
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${_t('msg_backup_success')} $path"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backup Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('lbl_restore')),
        content: Text(_t('msg_restore_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("RESTORE"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final success = await BackupService.restoreDatabase();
      if (success && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Restore Complete"),
            content: Text(_t('msg_restore_success')),
            actions: [
              TextButton(
                onPressed: () {
                   // Force logout to trigger a clean state on next login
                   ref.read(authProvider.notifier).logout();
                   Navigator.of(context).popUntil((route) => route.isFirst);
                }, 
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Restore Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    try {
      await BackupService.shareBackup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Share Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickBackupFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select your Cloud Sync Folder (OneDrive/Dropbox/etc)',
    );

    if (selectedDirectory != null) {
      setState(() {
        _autoBackupPath = selectedDirectory;
        _enableAutoBackup = true; // Auto-enable if they pick a folder
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider); 
    final printerState = ref.watch(printerProvider); // ✅ Listen to Global Printer State

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('title')),
        actions: [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. General
              Text(_t('sec_general'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _storeNameController,
                decoration: InputDecoration(
                  labelText: _t('lbl_store_name'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.money),
                title: Text(_t('lbl_currency')),
                trailing: DropdownButton<String>(
                  value: _currency,
                  items: const [
                    DropdownMenuItem(value: 'DZD', child: Text('DZD')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _currency = val);
                  },
                ),
              ),
              const SizedBox(height: 32),

              // 2. Receipt
              Text(_t('sec_receipt'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Divider(),
              const SizedBox(height: 16),
              
              // Logo
              Text(_t('lbl_logo'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    image: _logoPath != null
                        ? DecorationImage(image: FileImage(File(_logoPath!)), fit: BoxFit.contain)
                        : null,
                  ),
                  child: _logoPath == null
                      ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              // Footer
              TextFormField(
                controller: _footerController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _t('lbl_footer'),
                  border: const OutlineInputBorder(),
                  hintText: "Follow us on Instagram...",
                ),
              ),
              const SizedBox(height: 24),

              // Auto Print
              SwitchListTile(
                title: Text(_t('lbl_autoprint')),
                subtitle: const Text("Prints thermal receipt immediately after checkout"),
                value: _autoPrint,
                onChanged: (val) => setState(() => _autoPrint = val),
              ),
              // TABLES FEATURE
              SwitchListTile(
                title: Text(_t('lbl_enable_tables')),
                subtitle: Text(_t('sub_enable_tables')),
                value: _enableTables,
                onChanged: (val) {
                  setState(() => _enableTables = val);
                },
              ),
              const Divider(),
              
              const SizedBox(height: 16),
              
              // 3. Printer Setup (New Config)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Printer Setup (Pro Mode)", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  if (printerState.selectedPrinterName == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                      child: const Text("SIMULATION MODE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              // --- KITCHEN PRINTER SECTION ---
              Card(
                elevation: 0,
                color: Colors.blue.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.kitchen, color: Colors.blue),
                          const SizedBox(width: 10),
                          Text(_t('sec_kitchen'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_t('lbl_enable_kot')),
                        subtitle: Text(_t('sub_enable_kot')),
                        value: _enableKitchenPrinter,
                        onChanged: (val) => setState(() => _enableKitchenPrinter = val),
                      ),
                      if (_enableKitchenPrinter) ...[
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(labelText: _t('lbl_printer_type')),
                                value: _kitchenPrinterType,
                                items: const [
                                  DropdownMenuItem(value: 'usb', child: Text('USB')),
                                  DropdownMenuItem(value: 'network', child: Text('Network / LAN')),
                                ],
                                onChanged: (val) => setState(() => _kitchenPrinterType = val),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: _kitchenPrinterAddress,
                                decoration: InputDecoration(
                                  labelText: _kitchenPrinterType == 'network' ? 'IP Address (e.g. 192.168.1.50)' : 'Printer Name / ID',
                                  hintText: _kitchenPrinterType == 'network' ? '192.168.1.100' : 'POS-80',
                                ),
                                onChanged: (val) => _kitchenPrinterAddress = val,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_t('lbl_kot_autoprint')),
                          value: _autoPrintKot,
                          onChanged: (val) => setState(() => _autoPrintKot = val),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Printer Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Select Thermal Printer",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.print),
                ),
                value: printerState.devices.any((p) => p.name == _selectedPrinterName) ? _selectedPrinterName : null,
                items: printerState.devices.map((p) => DropdownMenuItem(
                  value: p.name,
                  child: Row(
                    children: [
                      Text(p.name),
                      if (printerState.isConnected && printerState.selectedPrinterName == p.name)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                        ),
                    ],
                  ),
                )).toList(),
                onChanged: (val) async {
                  if (val == null) return;
                  setState(() => _selectedPrinterName = val);
                  
                  final device = printerState.devices.firstWhere((p) => p.name == val);
                  bool success = await ref.read(printerProvider.notifier).connect(device);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? "✅ Connected to ${device.name}" : "❌ Failed to connect"),
                        backgroundColor: success ? Colors.green : Colors.red,
                      )
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                   Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                         String result = await PrinterService.testDrawer(); 
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Test Result: $result")));
                      },
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text("TEST DRAWER"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        foregroundColor: Colors.red.shade800,
                        side: BorderSide(color: Colors.red.shade800),
                      ),
                    ),
                   ),
                   const SizedBox(width: 10),
                   Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testPrint,
                      icon: const Icon(Icons.receipt_long),
                      label: const Text("TEST RECEIPT"),
                       style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                   ),
                ],
              ),

              const SizedBox(height: 32),

              // 4. Backup & Restore
              Text(_t('sec_maintenance'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
              const Divider(),
              const SizedBox(height: 8),
              
              Card(
                elevation: 0,
                color: Colors.red.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), 
                  side: BorderSide(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.share, color: Colors.green),
                      title: Text(_t('lbl_share')),
                      subtitle: Text(_t('sub_share')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _handleShare,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.cloud_sync, color: Colors.blue),
                      title: Text(_t('lbl_auto_backup')),
                      subtitle: Text(_autoBackupPath ?? _t('msg_auto_backup_off')),
                      value: _enableAutoBackup,
                      onChanged: _autoBackupPath == null ? null : (val) => setState(() => _enableAutoBackup = val),
                    ),
                    if (_enableAutoBackup || _autoBackupPath == null)
                      TextButton.icon(
                        onPressed: _pickBackupFolder,
                        icon: const Icon(Icons.folder_open),
                        label: Text(_t('lbl_pick_folder')),
                      ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined, color: Colors.blueGrey),
                      title: Text(_t('lbl_backup')),
                      subtitle: Text(_t('sub_backup')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _handleBackup,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_backup_restore, color: Colors.red),
                      title: Text(_t('lbl_restore')),
                      subtitle: Text(_t('sub_restore')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _handleRestore,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_t('btn_save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

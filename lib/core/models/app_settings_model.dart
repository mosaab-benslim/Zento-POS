// lib/core/models/app_settings_model.dart

class AppSettings {
  final int? id;
  final String currency;
  final double taxPercent;
  final String receiptFooter;
  final String? receiptLogoPath;
  final bool autoPrintReceipt;
  final String storeName; // ✅ Re-added field
  final bool enableTables; // ✅ Re-added field
  final String? printerAddress; // ✅ Persist printer
  final String? autoBackupPath; // ✅ Path for cloud/local auto-backup
  final bool enableAutoBackup; // ✅ Toggle for auto-backup on shift close
  final bool enableKitchenPrinter; // ✅ KOT
  final String? kitchenPrinterAddress; // ✅ KOT
  final String? kitchenPrinterType; // ✅ KOT (usb/network)
  final bool autoPrintKot; // ✅ KOT

  const AppSettings({
    this.id,
    this.currency = 'USD',
    this.taxPercent = 0.0,
    this.receiptFooter = 'Thank you for your business!',
    this.receiptLogoPath,
    this.autoPrintReceipt = false,
    this.storeName = 'My Restaurant',
    this.enableTables = false,
    this.printerAddress,
    this.autoBackupPath,
    this.enableAutoBackup = false,
    this.enableKitchenPrinter = false,
    this.kitchenPrinterAddress,
    this.kitchenPrinterType = 'usb',
    this.autoPrintKot = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'currency': currency,
      'tax_percent': taxPercent,
      'receipt_footer': receiptFooter,
      'receipt_logo_path': receiptLogoPath,
      'auto_print_receipt': autoPrintReceipt ? 1 : 0,
      'store_name': storeName,
      'enable_tables': enableTables ? 1 : 0,
      'printer_address': printerAddress,
      'auto_backup_path': autoBackupPath,
      'enable_auto_backup': enableAutoBackup ? 1 : 0,
      'enable_kitchen_printer': enableKitchenPrinter ? 1 : 0,
      'kitchen_printer_address': kitchenPrinterAddress,
      'kitchen_printer_type': kitchenPrinterType,
      'auto_print_kot': autoPrintKot ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      id: map['id'] as int?,
      currency: map['currency'] as String,
      taxPercent: (map['tax_percent'] as num).toDouble(),
      receiptFooter: map['receipt_footer'] as String,
      receiptLogoPath: map['receipt_logo_path'] as String?,
      autoPrintReceipt: (map['auto_print_receipt'] as int? ?? 0) == 1,
      storeName: map['store_name'] as String? ?? 'My Restaurant',
      enableTables: (map['enable_tables'] as int? ?? 0) == 1,
      printerAddress: map['printer_address'] as String?,
      autoBackupPath: map['auto_backup_path'] as String?,
      enableAutoBackup: (map['enable_auto_backup'] as int? ?? 0) == 1,
      enableKitchenPrinter: (map['enable_kitchen_printer'] as int? ?? 0) == 1,
      kitchenPrinterAddress: map['kitchen_printer_address'] as String?,
      kitchenPrinterType: map['kitchen_printer_type'] as String? ?? 'usb',
      autoPrintKot: (map['auto_print_kot'] as int? ?? 0) == 1,
    );
  }

  AppSettings copyWith({
    int? id,
    String? currency,
    double? taxPercent,
    String? receiptFooter,
    String? receiptLogoPath,
    bool? autoPrintReceipt,
    String? storeName,
    bool? enableTables,
    String? printerAddress,
    String? autoBackupPath,
    bool? enableAutoBackup,
    bool? enableKitchenPrinter,
    String? kitchenPrinterAddress,
    String? kitchenPrinterType,
    bool? autoPrintKot,
  }) {
    return AppSettings(
      id: id ?? this.id,
      currency: currency ?? this.currency,
      taxPercent: taxPercent ?? this.taxPercent,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      receiptLogoPath: receiptLogoPath ?? this.receiptLogoPath,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      storeName: storeName ?? this.storeName,
      enableTables: enableTables ?? this.enableTables,
      printerAddress: printerAddress ?? this.printerAddress,
      autoBackupPath: autoBackupPath ?? this.autoBackupPath,
      enableAutoBackup: enableAutoBackup ?? this.enableAutoBackup,
      enableKitchenPrinter: enableKitchenPrinter ?? this.enableKitchenPrinter,
      kitchenPrinterAddress: kitchenPrinterAddress ?? this.kitchenPrinterAddress,
      kitchenPrinterType: kitchenPrinterType ?? this.kitchenPrinterType,
      autoPrintKot: autoPrintKot ?? this.autoPrintKot,
    );
  }
}

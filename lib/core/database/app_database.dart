import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dbcrypt/dbcrypt.dart';
import '../models/user_model.dart'; // ✅ IMPORTANT

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    
    // Prevent race conditions
    if (_initDbFuture != null) return _initDbFuture!;
    
    _initDbFuture = _openDatabase();
    _database = await _initDbFuture;
    return _database!;
  }

  static Future<Database>? _initDbFuture;

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pos_system_v2.db');

    return openDatabase(
      path,
      version: 28, // V28: Add ingredient_stock_history
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA synchronous = NORMAL');
      },
      onOpen: (db) async {
        await ensurePermanentStaff(db);
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 23) {
      // V23: Add Manager Account
      try {
        final dbCrypt = DBCrypt();
        final managerHash = dbCrypt.hashpw('8888', dbCrypt.gensalt());
        
        // Check if manager already exists by name
        final List<Map<String, dynamic>> existing = await db.query(
          'users', 
          where: 'name = ?', 
          whereArgs: ['Manager']
        );

        if (existing.isEmpty) {
          await db.insert('users', {
            'name': 'Manager',
            'pin': managerHash,
            'role': UserRole.manager.index,
          });
        }
      } catch (e) {
        print("Migration V23 Error: $e");
      }
    }
    if (oldVersion < 18) {
      // V18: Expense Tracking
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            description TEXT NOT NULL,
            amount REAL NOT NULL,
            category TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      } catch (e) {
        print("Migration V18 Error: $e");
      }
    }
    // ... paths for 3, 4, 5, 6, 8, 9, 10
    if (oldVersion < 3) {
      // Add missing columns to categories table
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN colorValue INTEGER NOT NULL DEFAULT 4281538779'); // 0xFF3498DB
        await db.execute('ALTER TABLE categories ADD COLUMN isEnabled INTEGER NOT NULL DEFAULT 1');
      } catch (e) {
        // Handle if column already exists
      }
    }
    if (oldVersion < 4) {
      // Add imagePath to categories table
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN imagePath TEXT');
      } catch (e) {
        // Handle if column already exists
      }
    }
    if (oldVersion < 5) {
      // Update products table: add cost and isEnabled
      try {
        await db.execute('ALTER TABLE products ADD COLUMN cost REAL NOT NULL DEFAULT 0.0');
        await db.execute('ALTER TABLE products ADD COLUMN isEnabled INTEGER NOT NULL DEFAULT 1');
      } catch (e) {
        // Handle if column already exists
      }
    }
    if (oldVersion < 6) {
      // Create product_addons table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS product_addons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          productId INTEGER NOT NULL,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          isEnabled INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 8) {
      // 1. Add app_settings table
      await db.execute('DROP TABLE IF EXISTS app_settings');
      await db.execute('''
        CREATE TABLE app_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          currency TEXT NOT NULL DEFAULT 'USD',
          tax_percent REAL NOT NULL DEFAULT 0.0,
          receipt_footer TEXT NOT NULL DEFAULT 'Thank you!'
        )
      ''');

      // Insert default settings
      await db.insert('app_settings', {
        'currency': 'USD',
        'tax_percent': 0.0,
        'receipt_footer': 'Thank you for your business!',
      });

      // 2. Migrate existing users to BCrypt
      final dbCrypt = DBCrypt();
      final adminHash = dbCrypt.hashpw('12345678', dbCrypt.gensalt());
      final cashierHash = dbCrypt.hashpw('0000', dbCrypt.gensalt());

      await db.update('users', {'pin': adminHash}, where: 'name = ?', whereArgs: ['Admin']);
      await db.update('users', {'pin': cashierHash}, where: 'name = ?', whereArgs: ['Cashier']);
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE app_settings ADD COLUMN receipt_logo_path TEXT');
        await db.execute('ALTER TABLE app_settings ADD COLUMN auto_print_receipt INTEGER NOT NULL DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE app_settings ADD COLUMN store_name TEXT NOT NULL DEFAULT "My Restaurant"');
        await db.execute('ALTER TABLE orders ADD COLUMN queueNumber INTEGER NOT NULL DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN status INTEGER NOT NULL DEFAULT 0');
      } catch (e) {}
    }
    if (oldVersion < 12) {
      // V12: Tables Management
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tables (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('ALTER TABLE orders ADD COLUMN tableName TEXT');
        await db.execute('ALTER TABLE app_settings ADD COLUMN enable_tables INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        print("Migration V12 Error: $e");
      }
    }
    if (oldVersion < 13) {
      // V13: Printer Name Persistence
      try {
        await db.execute('ALTER TABLE app_settings ADD COLUMN printer_address TEXT');
      } catch (e) {
        print("Migration V13 Error: $e");
      }
    }
    if (oldVersion < 14) {
      // V14: Inventory Management
      try {
        // Add columns to products
        await db.execute('ALTER TABLE products ADD COLUMN stockQuantity INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE products ADD COLUMN trackStock INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE products ADD COLUMN alertLevel INTEGER NOT NULL DEFAULT 5');

        // Create stock_history table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            changeAmount INTEGER NOT NULL,
            reason TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Migration V14 Error: $e");
      }
    }

    if (oldVersion < 15) {
      // V15: Advanced Inventory (Ingredients & Recipes)
      try {
        // Create ingredients table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ingredients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            currentStock REAL NOT NULL DEFAULT 0,
            unit TEXT NOT NULL,
            costPerUnit REAL NOT NULL DEFAULT 0,
            reorderLevel REAL NOT NULL DEFAULT 0
          )
        ''');

        // Create product_ingredients (Recipes) table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS product_ingredients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            productId INTEGER NOT NULL,
            ingredientId INTEGER NOT NULL,
            quantityNeeded REAL NOT NULL,
            ingredientUnit TEXT,
            FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE,
            FOREIGN KEY (ingredientId) REFERENCES ingredients (id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        print("Migration V15 Error: $e");
      }
    }

    if (oldVersion < 17) {
      // V17: Stock Receiving (Batches)
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_batches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplierName TEXT NOT NULL,
            invoiceNumber TEXT NOT NULL,
            invoiceImagePath TEXT,
            totalCost REAL NOT NULL,
            receivedDate TEXT NOT NULL,
            notes TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_batch_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            batchId INTEGER NOT NULL,
            ingredientId INTEGER NOT NULL,
            ingredientName TEXT NOT NULL, 
            quantityReceived REAL NOT NULL,
            costPerUnit REAL NOT NULL,
            subtotal REAL NOT NULL,
            expiryDate TEXT,
            FOREIGN KEY (batchId) REFERENCES stock_batches (id) ON DELETE CASCADE,
            FOREIGN KEY (ingredientId) REFERENCES ingredients (id)
          )
        ''');
      } catch (e) {
        print("Migration V17 Error: $e");
      }
    }
    if (oldVersion < 19) {
      // V19: Shift Management
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shifts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId INTEGER NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT,
            openingCash REAL NOT NULL,
            closingCash REAL,
            totalSales REAL NOT NULL DEFAULT 0.0,
            totalCashSales REAL NOT NULL DEFAULT 0.0,
            totalCardSales REAL NOT NULL DEFAULT 0.0,
            expectedCash REAL NOT NULL DEFAULT 0.0,
            cashDifference REAL NOT NULL DEFAULT 0.0,
            status TEXT NOT NULL DEFAULT 'OPEN',
            FOREIGN KEY (userId) REFERENCES users (id)
          )
        ''');
        await db.execute('ALTER TABLE orders ADD COLUMN shiftId INTEGER');
        await db.execute('ALTER TABLE orders ADD COLUMN paymentMethod INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        print("Migration V19 Error: $e");
      }
    }

    if (oldVersion < 21) {
      // V21: Indexing for Performance (10k+ orders support)
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_timestamp ON orders (timestamp)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_orderId ON order_items (orderId)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_history_productId ON stock_history (productId)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_endTime ON shifts (endTime)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_products_stock ON products (trackStock, stockQuantity)');
      } catch (e) {
        print("Migration V21 Error: $e");
      }
    }

    if (oldVersion < 22) {
      // V22: Pro Backups (Auto-Cloud & Email)
      try {
        await db.execute('ALTER TABLE app_settings ADD COLUMN auto_backup_path TEXT');
        await db.execute('ALTER TABLE app_settings ADD COLUMN enable_auto_backup INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        print("Migration V22 Error: $e");
      }
    }

    if (oldVersion < 24) {
      // V24: pin_length for Login UI
      try {
        await db.execute('ALTER TABLE users ADD COLUMN pin_length INTEGER NOT NULL DEFAULT 4');
        // Update Admin to 8
        await db.update('users', {'pin_length': 8}, where: 'name = ?', whereArgs: ['Admin']);
      } catch (e) {
        print("Migration V24 Error: $e");
      }
    }

    if (oldVersion < 25) {
      // V25: KOT System
      try {
        // 1. Order Items Modifiers
        await db.execute('ALTER TABLE order_items ADD COLUMN modifiers TEXT');

        // 2. Order Timestamps & Status
        await db.execute('ALTER TABLE orders ADD COLUMN preparing_at INTEGER');
        await db.execute('ALTER TABLE orders ADD COLUMN ready_at INTEGER');
        await db.execute('ALTER TABLE orders ADD COLUMN kot_printed_at INTEGER');

        // 3. App Settings for Kitchen Printer
        await db.execute('ALTER TABLE app_settings ADD COLUMN enable_kitchen_printer INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE app_settings ADD COLUMN kitchen_printer_address TEXT');
        await db.execute('ALTER TABLE app_settings ADD COLUMN kitchen_printer_type TEXT DEFAULT "usb"');
        await db.execute('ALTER TABLE app_settings ADD COLUMN auto_print_kot INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        print("Migration V25 Error: $e");
      }
    }
    if (oldVersion < 26) {
      // V26: Reset default PINs and force correct lengths
      try {
        final dbCrypt = DBCrypt();
        
        // Admin -> 12345678 (8)
        await db.update('users', {
          'pin': dbCrypt.hashpw('12345678', dbCrypt.gensalt()),
          'pin_length': 8,
        }, where: 'name = ?', whereArgs: ['Admin']);

        // Manager -> 1234 (4)
        await db.update('users', {
          'pin': dbCrypt.hashpw('1234', dbCrypt.gensalt()),
          'pin_length': 4,
        }, where: 'name = ?', whereArgs: ['Manager']);

        // Cashier -> 0000 (4)
        await db.update('users', {
          'pin': dbCrypt.hashpw('0000', dbCrypt.gensalt()),
          'pin_length': 4,
        }, where: 'name = ?', whereArgs: ['Cashier']);

        // Final Defensive Check: Ensure KOT columns exist in app_settings (in case v25 failed)
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN enable_kitchen_printer INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN kitchen_printer_address TEXT'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN kitchen_printer_type TEXT DEFAULT "usb"'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN auto_print_kot INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        
        // Ensure KOT columns exist in orders
        try { await db.execute('ALTER TABLE orders ADD COLUMN preparing_at INTEGER'); } catch(_) {}
        try { await db.execute('ALTER TABLE orders ADD COLUMN ready_at INTEGER'); } catch(_) {}
        try { await db.execute('ALTER TABLE orders ADD COLUMN kot_printed_at INTEGER'); } catch(_) {}
        
        // Ensure modifiers exist in order_items
        try { await db.execute('ALTER TABLE order_items ADD COLUMN modifiers TEXT'); } catch(_) {}

      } catch (e) {
        print("Migration V26 Error: $e");
      }
    }
    if (oldVersion < 27) {
      // V27: FORCED REPAIR OF MISSING COLUMNS
      try {
        print("Starting V27 Forced Schema Repair...");
        
        // App Settings
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN enable_kitchen_printer INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN kitchen_printer_address TEXT'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN kitchen_printer_type TEXT DEFAULT "usb"'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN auto_print_kot INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN store_name TEXT NOT NULL DEFAULT "Zento POS"'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN enable_tables INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN auto_backup_path TEXT'); } catch(_) {}
        try { await db.execute('ALTER TABLE app_settings ADD COLUMN enable_auto_backup INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        
        // Orders
        try { await db.execute('ALTER TABLE orders ADD COLUMN preparing_at INTEGER'); } catch(_) {}
        try { await db.execute('ALTER TABLE orders ADD COLUMN ready_at INTEGER'); } catch(_) {}
        try { await db.execute('ALTER TABLE orders ADD COLUMN kot_printed_at INTEGER'); } catch(_) {}
        try { await db.execute('ALTER TABLE orders ADD COLUMN shiftId INTEGER'); } catch(_) {}
        try { await db.execute('ALTER TABLE orders ADD COLUMN paymentMethod INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        try { await db.execute('ALTER TABLE orders ADD COLUMN queueNumber INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        try { await db.execute('ALTER TABLE orders ADD COLUMN status INTEGER NOT NULL DEFAULT 0'); } catch(_) {}
        try { await db.execute('ALTER TABLE orders ADD COLUMN tableName TEXT'); } catch(_) {}

        // Order Items
        try { await db.execute('ALTER TABLE order_items ADD COLUMN modifiers TEXT'); } catch(_) {}

        print("V27 Forced Schema Repair Completed Successfully.");
      } catch (e) {
        print("Migration V27 Error: $e");
      }
    }
    if (oldVersion < 28) {
      // V28: Ingredient Stock History & Audit
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ingredient_stock_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ingredientId INTEGER NOT NULL,
            changeAmount REAL NOT NULL,
            reason TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            FOREIGN KEY (ingredientId) REFERENCES ingredients (id) ON DELETE CASCADE
          )
        ''');
        
        // Add index for performance
        await db.execute('CREATE INDEX IF NOT EXISTS idx_ingredient_stock_history_ingId ON ingredient_stock_history (ingredientId)');
        
        // Ensure standard users exist immediately in V28
        await ensurePermanentStaff(db);
      } catch (e) {
        print("Migration V28 Error: $e");
      }
    }
  }

  /// ✅ NEW: Guaranteed Staff Seeding
  /// Ensures Admin, Manager, and Cashier always exist (never "lost")
  static Future<void> ensurePermanentStaff(Database db) async {
    final dbCrypt = DBCrypt();
    
    // Check Admin (index 0)
    final adminList = await db.query('users', where: 'role = ?', whereArgs: [UserRole.admin.index]);
    if (adminList.isEmpty) {
      await db.insert('users', {
        'name': 'Admin',
        'pin': dbCrypt.hashpw('12345678', dbCrypt.gensalt()),
        'pin_length': 8,
        'role': UserRole.admin.index,
      });
    }

    // Check Manager (index 2)
    final managerList = await db.query('users', where: 'role = ?', whereArgs: [UserRole.manager.index]);
    if (managerList.isEmpty) {
      await db.insert('users', {
        'name': 'Manager',
        'pin': dbCrypt.hashpw('1234', dbCrypt.gensalt()),
        'pin_length': 4,
        'role': UserRole.manager.index,
      });
    }

    // Check Cashier (index 1)
    final cashierList = await db.query('users', where: 'role = ?', whereArgs: [UserRole.cashier.index]);
    if (cashierList.isEmpty) {
      await db.insert('users', {
        'name': 'Cashier',
        'pin': dbCrypt.hashpw('0000', dbCrypt.gensalt()),
        'pin_length': 4,
        'role': UserRole.cashier.index,
      });
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // ───────── USERS ─────────
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pin TEXT NOT NULL UNIQUE,
        pin_length INTEGER NOT NULL DEFAULT 4,
        role INTEGER NOT NULL
      )
    ''');

    // 🔐 DEFAULT USERS (BOOTSTRAP) - BCrypt Hashed PINs
    final dbCrypt = DBCrypt();
    
    // Admin: 12345678 (8 digits)
    await db.insert('users', {
      'name': 'Admin',
      'pin': dbCrypt.hashpw('12345678', dbCrypt.gensalt()),
      'pin_length': 8,
      'role': UserRole.admin.index,
    });

    // Manager: 1234 (4 digits)
    await db.insert('users', {
      'name': 'Manager',
      'pin': dbCrypt.hashpw('1234', dbCrypt.gensalt()),
      'pin_length': 4,
      'role': UserRole.manager.index,
    });

    // Cashier: 0000 (4 digits)
    await db.insert('users', {
      'name': 'Cashier',
      'pin': dbCrypt.hashpw('0000', dbCrypt.gensalt()),
      'pin_length': 4,
      'role': UserRole.cashier.index,
    });

    // ───────── CATEGORIES ─────────
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        orderIndex INTEGER NOT NULL DEFAULT 0,
        colorValue INTEGER NOT NULL DEFAULT 4281538779,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        imagePath TEXT
      )
    ''');

    // ───────── PRODUCTS ─────────
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoryId INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        cost REAL NOT NULL DEFAULT 0.0,
        imagePath TEXT,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        stockQuantity INTEGER NOT NULL DEFAULT 0,
        trackStock INTEGER NOT NULL DEFAULT 0,
        alertLevel INTEGER NOT NULL DEFAULT 5,
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // ───────── PRODUCT ADDONS ─────────
    await db.execute('''
      CREATE TABLE product_addons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
    
    // ───────── STOCK HISTORY ─────────
    await db.execute('''
      CREATE TABLE stock_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        changeAmount INTEGER NOT NULL,
        reason TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // ───────── ORDERS ─────────
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cashierId INTEGER NOT NULL,
        shiftId INTEGER,
        totalAmount REAL NOT NULL,
        orderType INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        queueNumber INTEGER NOT NULL DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 0,
        tableName TEXT,
        paymentMethod INTEGER NOT NULL DEFAULT 0,
        preparing_at INTEGER,
        ready_at INTEGER,
        kot_printed_at INTEGER,
        FOREIGN KEY (cashierId) REFERENCES users (id),
        FOREIGN KEY (shiftId) REFERENCES shifts (id)
      )
    ''');

    // ───────── ORDER ITEMS ─────────
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        priceAtTime REAL NOT NULL,
        modifiers TEXT,
        FOREIGN KEY (orderId) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES products (id)
      )
    ''');

    // ───────── RESTAURANT TABLES ─────────
    await db.execute('''
      CREATE TABLE tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // ───────── APP SETTINGS ─────────
    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        currency TEXT NOT NULL DEFAULT 'USD',
        tax_percent REAL NOT NULL DEFAULT 0.0,
        receipt_footer TEXT NOT NULL DEFAULT 'Thank you!',
        receipt_logo_path TEXT,
        auto_print_receipt INTEGER NOT NULL DEFAULT 0,
        store_name TEXT NOT NULL DEFAULT 'Zento POS',
        enable_tables INTEGER NOT NULL DEFAULT 0,
        printer_address TEXT,
        auto_backup_path TEXT,
        enable_auto_backup INTEGER NOT NULL DEFAULT 0,
        enable_kitchen_printer INTEGER NOT NULL DEFAULT 0,
        kitchen_printer_address TEXT,
        kitchen_printer_type TEXT DEFAULT 'usb',
        auto_print_kot INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.insert('app_settings', {
      'currency': 'USD',
      'tax_percent': 0.0,
      'receipt_footer': 'Thank you for your business!',
      'receipt_logo_path': null,
      'auto_print_receipt': 0,
      'store_name': 'Zento POS',
      'enable_tables': 0,
      'printer_address': null,
      'enable_kitchen_printer': 0,
      'auto_print_kot': 0,
    });

    // ───────── INGREDIENTS (V15) ─────────
    await db.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        currentStock REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL,
        costPerUnit REAL NOT NULL DEFAULT 0,
        reorderLevel REAL NOT NULL DEFAULT 0
      )
    ''');

    // Create product_ingredients (Recipes) table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        ingredientId INTEGER NOT NULL,
        quantityNeeded REAL NOT NULL,
        ingredientUnit TEXT,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE,
        FOREIGN KEY (ingredientId) REFERENCES ingredients (id) ON DELETE CASCADE
      )
    ''');

    // ───────── STOCK BATCHES (V17) ─────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplierName TEXT NOT NULL,
        invoiceNumber TEXT NOT NULL,
        invoiceImagePath TEXT,
        totalCost REAL NOT NULL,
        receivedDate TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_batch_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batchId INTEGER NOT NULL,
        ingredientId INTEGER NOT NULL,
        ingredientName TEXT NOT NULL, 
        quantityReceived REAL NOT NULL,
        costPerUnit REAL NOT NULL,
        subtotal REAL NOT NULL,
        expiryDate TEXT,
        FOREIGN KEY (batchId) REFERENCES stock_batches (id) ON DELETE CASCADE,
        FOREIGN KEY (ingredientId) REFERENCES ingredients (id)
      )
    ''');

    // ───────── EXPENSES (V18) ─────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        shiftId INTEGER,
        wasPaidFromDrawer INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ───────── SHIFTS (V19) ─────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        openingCash REAL NOT NULL,
        closingCash REAL,
        totalSales REAL NOT NULL DEFAULT 0.0,
        totalCashSales REAL NOT NULL DEFAULT 0.0,
        totalCardSales REAL NOT NULL DEFAULT 0.0,
        expectedCash REAL NOT NULL DEFAULT 0.0,
        cashDifference REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'OPEN',
        FOREIGN KEY (userId) REFERENCES users (id)
      )
    ''');

    // ───────── INDICES (V21) ─────────
    await db.execute('CREATE INDEX IF NOT EXISTS idx_orders_timestamp ON orders (timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_items_orderId ON order_items (orderId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_history_productId ON stock_history (productId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_endTime ON shifts (endTime)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_stock ON products (trackStock, stockQuantity)');

    // ───────── INGREDIENT STOCK HISTORY (V28) ─────────
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingredient_stock_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredientId INTEGER NOT NULL,
        changeAmount REAL NOT NULL,
        reason TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (ingredientId) REFERENCES ingredients (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ingredient_stock_history_ingId ON ingredient_stock_history (ingredientId)');
  }
}

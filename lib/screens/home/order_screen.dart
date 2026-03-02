import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/core/providers/product_provider.dart';
import 'package:zento_pos/core/providers/category_provider.dart';
import 'package:zento_pos/main.dart'; // Access orderProvider
import 'package:zento_pos/core/providers/auth_provider.dart';
import 'package:zento_pos/core/repositories/order_repository.dart';
import 'package:zento_pos/core/models/product_model.dart';
import 'package:zento_pos/core/models/order_model.dart'; // Added
import 'package:zento_pos/core/models/cart_item_model.dart';
import 'package:zento_pos/core/models/order_item_model.dart';
import 'package:zento_pos/core/logic/order_logic.dart'; // For OrderState/Notifier
import 'package:zento_pos/core/utils/currency_helper.dart';
import 'package:zento_pos/core/models/app_settings_model.dart';
import 'package:zento_pos/core/repositories/app_settings_repository.dart';
import 'package:zento_pos/core/utils/receipt_helper.dart';
import 'dart:io';
import '../../enums/app_language.dart';
import '../auth/login_screen.dart'; // ✅ Added for Logout
import 'widgets/table_selection_dialog.dart'; // ✅ Tables Feature
import 'package:zento_pos/core/models/table_model.dart';
import 'package:zento_pos/screens/pos/shifts/shift_dialog_widgets.dart';
import 'package:zento_pos/main.dart'; // ✅ Added for scaffoldMessengerKey
import 'package:zento_pos/core/providers/shift_provider.dart';
import 'package:zento_pos/core/constants/translations.dart';

// --- MAIN SCREEN ---
class OrderScreen extends ConsumerStatefulWidget {
  const OrderScreen({super.key});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  // --- STATE ---
  String? _selectedCategoryName; 
  int? _selectedCategoryId;
  bool _isLoading = false;
  bool _isProcessingPayment = false; // ✅ Guard for double-clicks
  String? _selectedTableName;
  bool _enableTables = false;
  bool _showUtilityTube = false; // ✅ Utility Tube State
  bool _isResuming = false; // ✅ Guard for pending slips

  String _t(String key) {
    return AppTranslations.t(ref.watch(languageProvider), key);
  }

  @override
  void initState() {
    super.initState();
    _loadFeatureSettings();

    // Initial Load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(categoryProvider.notifier).loadCategories();
      ref.read(productProvider.notifier).loadProducts();
    });
  }

  Future<void> _loadFeatureSettings() async {
     final settingsRepo = ref.read(appSettingsRepositoryProvider);
     final settings = await settingsRepo.getSettings();
     if (settings != null && mounted) {
       setState(() {
         _enableTables = settings.enableTables;
       });
     }
  }


  void _cycleLanguage() {
    final current = ref.read(languageProvider);
    final next = AppLanguage.values[(AppLanguage.values.indexOf(current) + 1) % AppLanguage.values.length];
    ref.read(languageProvider.notifier).setLanguage(next);
  }

  void _logout() {
    // 🔥 Clear session and order state
    ref.read(authProvider.notifier).logout();
    ref.read(orderProvider.notifier).clearOrder();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  // --- LOGIC ---

  void _onCategorySelected(int categoryId) {
    setState(() => _selectedCategoryId = categoryId);
  }

  void _addToCart(Product product) {
    if (product.addons.isNotEmpty) {
      _showModifierPopup(product);
    } else {
      ref.read(orderProvider.notifier).addProduct(product);
    }
  }

  void _showModifierPopup(Product product) {
    List<ProductAddon> selectedAddons = [];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("${_t('customize')} ${product.name}"),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: product.addons.length,
              itemBuilder: (context, index) {
                final addon = product.addons[index];
                if (!addon.isEnabled) return const SizedBox.shrink();
                
                final isSelected = selectedAddons.contains(addon);
                return CheckboxListTile(
                  title: Text("${addon.name} (+${CurrencyHelper.format(addon.priceCents)})"),
                  value: isSelected,
                  onChanged: (v) {
                    setModalState(() {
                      if (v == true) {
                        selectedAddons.add(addon);
                      } else {
                        selectedAddons.remove(addon);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text(_t("cancel"))
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(orderProvider.notifier).addProduct(product, addons: selectedAddons);
                Navigator.pop(context);
              },
              child: Text(_t("apply")),
            )
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---
  void _showPaymentModal(int subtotal, String? tableName) {
     final lang = ref.read(languageProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        content: Container(
          width: 400,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_t("finalize_payment"), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              _paymentOption(Icons.payments, _t("cash"), Colors.green, lang, tableName),
              const SizedBox(height: 15),
              _paymentOption(Icons.credit_card, _t("card_cib_edahavia"), Colors.blue, lang, tableName),
              if (ref.read(orderProvider).orderType == OrderType.delivery) ...[
                const SizedBox(height: 15),
                _paymentOption(Icons.moped, _t("pay_on_delivery"), Colors.orange, lang, tableName),
              ],
              const SizedBox(height: 30),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(_t("back_to_order"))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentOption(IconData icon, String label, Color color, AppLanguage lang, String? tableName) {
    return InkWell(
      onTap: () async {
        if (_isProcessingPayment) return; // 🛑 Guard: Don't process twice
        
        setState(() => _isProcessingPayment = true);
        try {
          // ✅ Shift Check with AUTO-RESUME
          if (ref.read(shiftProvider).isLoading) {
            // Show feedback
            scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text("🗄️ Finishing background sync... Payment will resume automatically."), 
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );

            // 🔥 EVENT-DRIVEN RESUME: Wait for the provider's completer
            await ref.read(shiftProvider.notifier).waitForSync();
          }

          // Re-read current state after waiting
          final shiftState = ref.read(shiftProvider);

          if (shiftState.activeShift == null) {
            ShiftDialogs.showOpenShift(context, ref);
            return;
          }

          if (context.mounted) Navigator.pop(context); // ✅ Close modal immediately
          final authState = ref.read(authProvider);
        final cashierId = authState.currentUser?.id ?? 1;

        final preparedOrder = ref.read(orderProvider.notifier).prepareOrder(cashierId: cashierId); 
        if (preparedOrder != null) {
          // Determine payment method
          final paymentMethod = label == _t("cash") 
              ? PaymentMethod.cash 
              : (label == _t("card_cib_edahavia") ? PaymentMethod.card : PaymentMethod.payOnDelivery);

          // ... visual feedback code ...
          String printMsg = preparedOrder.wasResumed
              ? (lang == AppLanguage.en ? 'Printing Customer Receipt...' : 'Impression Ticket Client...')
              : (lang == AppLanguage.en ? 'Printing Kitchen & Customer Receipts...' : 'Impression Tickets (Cuisine + Client)...');

          if (context.mounted) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text("🖨️ $printMsg"),
                duration: const Duration(seconds: 2),
                backgroundColor: const Color(0xFF1E293B),
              ),
            );
          }

          // ✅ Attach Table Name, Payment Method, and Shift ID
          final orderWithExtras = preparedOrder.order.copyWith(
            tableName: tableName,
            paymentMethod: paymentMethod,
            shiftId: shiftState.activeShift!.id,
            status: OrderStatus.completed, // 🔥 CRITICAL: Mark as completed so it's NOT a pending slip
          );
          
          final repo = ref.read(orderRepositoryProvider);
          final result = await repo.createOrder(orderWithExtras, preparedOrder.items);
          if (result.isSuccess) {
            // ✅ Delete the original resumed order from DB if this was a resumption
            final resumedId = ref.read(orderProvider).resumedOrderId;
            if (resumedId != null) {
              await repo.deleteOrder(resumedId);
              ref.invalidate(pendingOrdersProvider);
            }

            // ✅ Clear Cart & Table Selection
            ref.read(orderProvider.notifier).clearOrder();
            setState(() => _selectedTableName = null);
            
            final finalizedOrder = result.value;
            ref.read(orderProvider.notifier).refreshQueueNumber();
            if (finalizedOrder.id != null) {
              // _showReceiptPreview(finalizedOrder, context, ref); // This line was in the user's snippet, but not in the original. Assuming it's a future change or typo.
            }
            final settingsRepo = ref.read(appSettingsRepositoryProvider);
            final settings = await settingsRepo.getSettings() ?? const AppSettings();
            
            String msg = (lang == AppLanguage.en ? 'Order Saved via' : (lang == AppLanguage.fr ? 'Commande via' : 'تم الطلب بواسطة')) + " " + label;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
            
            // ✅ ALWAYS SHOW RECEIPT PREVIEW (Requested by user)
            ReceiptHelper.showReceiptPreview(
              context: context,
              order: finalizedOrder,
              items: preparedOrder.items,
              settings: settings,
              lang: lang,
              openCashDrawer: paymentMethod == PaymentMethod.cash, // Only open if cash
              forceSolitaryCustomer: preparedOrder.wasResumed, // 🔥 Skip kitchen if it was already held/printed
            );
          }
        }
      } catch (e) {
        debugPrint("Payment Error: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isProcessingPayment = false);
      }
    },
    child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(15),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 20),
            Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final categories = ref.watch(categoryProvider);
    final isRtl = language == AppLanguage.ar;

    // Initial Selection logic - safer to handle within Build if we check for changes
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            Row(
              children: [
                // 1️⃣ PROFESSIONAL SIDEBAR
                Container(
                  width: 110,
                  color: const Color(0xFF0F172A), // Darker, more premium slate
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // --- CATEGORIES (Scrolling) ---
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final cat = categories[index];
                              bool isSel = _selectedCategoryId == cat.id;
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: InkWell(
                                  onTap: () => _onCategorySelected(cat.id!),
                                  borderRadius: BorderRadius.circular(18),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: isSel ? Color(cat.colorValue) : Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: isSel ? [
                                        BoxShadow(
                                          color: Color(cat.colorValue).withOpacity(0.4), 
                                          blurRadius: 15, 
                                          offset: const Offset(0, 5)
                                        ),
                                      ] : [],
                                      border: Border.all(
                                        color: isSel ? Colors.white.withOpacity(0.2) : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Side Accent Border (Pro POS Style)
                                        if (isSel)
                                          Positioned(
                                            left: 0,
                                            top: 15,
                                            bottom: 15,
                                            child: Container(
                                              width: 5,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                                          child: Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                cat.name, // Clean name without emojis
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                style: TextStyle(
                                                  color: isSel ? Colors.white : Colors.white54, 
                                                  fontSize: 13, 
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.2,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // --- TUBE ARROW (Bottom) ---
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20, top: 10),
                          child: FloatingActionButton.small(
                            onPressed: () => setState(() => _showUtilityTube = !_showUtilityTube),
                            backgroundColor: _showUtilityTube ? Colors.orangeAccent : Colors.white.withOpacity(0.05),
                            elevation: 0,
                            child: AnimatedRotation(
                              duration: const Duration(milliseconds: 300),
                              turns: _showUtilityTube ? (isRtl ? -0.25 : 0.25) : 0,
                              child: Icon(
                                isRtl ? Icons.chevron_left : Icons.chevron_right, 
                                color: _showUtilityTube ? Colors.black : Colors.white70
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2️⃣ PENDING SLIPS (Fixed width, independent scroll)
                RepaintBoundary(child: _buildPendingSidebar()),

                // 3️⃣ MAIN CONTENT AREA
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: _selectedCategoryId != null 
                          ? ProductGrid(categoryId: _selectedCategoryId!)
                          : categories.isEmpty 
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text(_t('no_categories_found'), style: const TextStyle(color: Colors.grey, fontSize: 18)),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        ref.read(categoryProvider.notifier).seedSampleData();
                                      },
                                      icon: const Icon(Icons.auto_awesome), 
                                      label: Text(_t('seed_sample_data'))
                                    ),
                                  ],
                                ),
                               )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
                ),

                // 4️⃣ RIGHT ORDER SIDEBAR
                Container(
                  width: 380,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                  ),
                  child: _CartSidebar(
                    tableName: _selectedTableName,
                    onOrderSuccess: () => setState(() => _selectedTableName = null),
                    onPlaceOrder: (sub) => _showPaymentModal(sub, _selectedTableName),
                  ),
                ),
              ],
            ),

            // 🚀 THE UTILITY TUBE (Animated Overlay)
            _buildUtilityTube(isRtl),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilityTube(bool isRtl) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      bottom: 20,
      // ✅ Completely move it off screen bounds when hidden
      left: !isRtl ? (_showUtilityTube ? 120 : -1000) : null,
      right: isRtl ? (_showUtilityTube ? 120 : -1000) : null,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Language
            _tubeAction(
              icon: Icons.language, 
              label: ref.watch(languageProvider).label, // Show CURRENT label
              color: Colors.blueAccent,
              onTap: _cycleLanguage,
            ),
            _tubeDivider(),
            // Close Shift
            _tubeAction(
              icon: Icons.timer_off_outlined, 
              label: AppTranslations.t(ref.read(languageProvider), 'btn_close_shift'),
              color: Colors.orangeAccent,
              onTap: () => ShiftDialogs.showCloseShift(context, ref),
            ),
            _tubeDivider(),
            // Logout
            _tubeAction(
              icon: Icons.logout, 
              label: _t('logout'),
              color: Colors.redAccent,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tubeAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tubeDivider() {
    return Container(
      width: 1,
      height: 25,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15), // Tightened for better space
      color: Colors.white,
      child: Row(
        children: [
          // 🚀 LEFT: Order # & Table
          const _OrderNumberAndClock(),
          if (_enableTables) ...[
            const SizedBox(width: 12), // Reduced gap
            Flexible(
              flex: 1, 
              child: InkWell(
                onTap: () async {
                  final table = await showDialog<TableModel>(
                    context: context,
                    builder: (context) => const TableSelectionDialog(),
                  );
                  if (table != null) {
                    setState(() => _selectedTableName = table.name);
                  }
                },
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced horizontal padding
                  decoration: BoxDecoration(
                    color: _selectedTableName != null ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _selectedTableName != null ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.table_bar_rounded,
                        size: 20,
                        color: _selectedTableName != null ? Colors.blue : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _selectedTableName ?? _t('select_table'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13, // Slightly smaller base
                              color: _selectedTableName != null ? Colors.blue.shade700 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      if (_selectedTableName != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _selectedTableName = null),
                          child: const Icon(Icons.close, size: 14, color: Colors.blue),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(width: 8), // Minimal gap
          
          // 🏗️ RIGHT: Order Type Toggle
          const Flexible(
            flex: 2, // Higher priority for three-option toggle
            child: Align(
              alignment: Alignment.centerRight,
              child: _OrderTypeToggle(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBtn(String label, IconData icon, OrderType type, OrderType currentType) {
    bool isSel = type == currentType;
    return GestureDetector(
      onTap: () => ref.read(orderProvider.notifier).setOrderType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSel ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSel ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : [],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSel ? Colors.black : Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSel ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }

  // _buildProductGrid removed in favor of ProductGrid class


  Widget _buildPendingSidebar() {
    final pendingOrdersAsync = ref.watch(pendingOrdersProvider);
    final products = ref.watch(productProvider);
    final items = ref.watch(orderProvider).items;

    return Container(
      width: 140,
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          const SizedBox(height: 50),
          Text(_t('pending_orders'),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF1E293B))),
          const Divider(),
          Expanded(
            child: pendingOrdersAsync.when(
              data: (orders) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final now = DateTime.now();
                  final diff = now.difference(order.createdAt).inMinutes;

                  return GestureDetector(
                    onTap: (items.isNotEmpty || _isResuming)
                        ? null
                        : () async {
                            setState(() => _isResuming = true);
                            try {
                              final repo = ref.read(orderRepositoryProvider);
                              final oItems = await repo.getOrderItems(order.id!);
                              ref.read(orderProvider.notifier).resumeOrder(
                                    order: order,
                                    items: oItems,
                                    allProducts: products,
                                    ref: ref,
                                  );
                            } finally {
                              if (mounted) setState(() => _isResuming = false);
                            }
                          },
                    child: Opacity(
                      opacity: (items.isNotEmpty || _isResuming) ? 0.5 : 1.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5)
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("#${order.queueNumber}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 18)),
                            Text(CurrencyHelper.format(order.totalCents),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    fontSize: 11)),
                            const SizedBox(height: 4),
                            Text("$diff ${_t('mins_ago')}",
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                  child: Icon(Icons.error_outline, color: Colors.red.shade300)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OPTIMIZED SUB-WIDGETS ───

class _OrderNumberAndClock extends ConsumerStatefulWidget {
  const _OrderNumberAndClock();

  @override
  ConsumerState<_OrderNumberAndClock> createState() => _OrderNumberAndClockState();
}

class _OrderNumberAndClockState extends ConsumerState<_OrderNumberAndClock> {
  late Timer _timer;
  String _time = "";

  @override
  void initState() {
    super.initState();
    _time = DateFormat('HH:mm:ss').format(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _time = DateFormat('HH:mm:ss').format(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueNum = ref.watch(orderProvider.select((s) => s.queueNumber));
    final lang = ref.watch(languageProvider);
    final label = lang == AppLanguage.en ? 'Order #' : (lang == AppLanguage.fr ? 'Commande #' : 'الطلب #');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label${queueNum.toString().padLeft(3, '0')}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(_time, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _OrderTypeToggle extends ConsumerWidget {
  const _OrderTypeToggle();

  @override
  String _t(String key, AppLanguage lang) {
    switch (key) {
      case 'dine_in':
        return lang == AppLanguage.en ? 'Dine-In' : (lang == AppLanguage.fr ? 'Sur Place' : 'محلي');
      case 'takeaway':
        return lang == AppLanguage.en ? 'Takeaway' : (lang == AppLanguage.fr ? 'Emporter' : 'سفري');
      case 'delivery':
        return lang == AppLanguage.en ? 'Delivery' : (lang == AppLanguage.fr ? 'Livraison' : 'توصيل');
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderState = ref.watch(orderProvider);
    final current = orderState.orderType;
    final lang = ref.watch(languageProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max, // Fill the available space
        children: [
          Expanded(child: _btn(ref, _t('dine_in', lang), Icons.restaurant, OrderType.dineIn, current)),
          Expanded(child: _btn(ref, _t('takeaway', lang), Icons.shopping_bag, OrderType.takeaway, current)),
          Expanded(child: _btn(ref, _t('delivery', lang), Icons.delivery_dining, OrderType.delivery, current)),
        ],
      ),
    );
  }

  Widget _btn(WidgetRef ref, String label, IconData icon, OrderType target, OrderType current) {
    bool isSel = target == current;
    return GestureDetector(
      onTap: () => ref.read(orderProvider.notifier).setOrderType(target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), // Minimal padding for extreme space
        decoration: BoxDecoration(
          color: isSel ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSel ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSel ? Colors.black : Colors.grey),
            const SizedBox(width: 4),
            Flexible( // 🛡️ CRITICAL: Forces FittedBox to respect Row width
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSel ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSidebar extends ConsumerStatefulWidget {
  final String? tableName;
  final VoidCallback onOrderSuccess;
  final void Function(int) onPlaceOrder;

  const _CartSidebar({
    super.key,
    required this.tableName,
    required this.onOrderSuccess,
    required this.onPlaceOrder,
  });

  @override
  ConsumerState<_CartSidebar> createState() => _CartSidebarState();
}

class _CartSidebarState extends ConsumerState<_CartSidebar> {
  bool _isProcessingHold = false;

  String _t(String key, AppLanguage lang) {
    if (key == 'current_order') return lang == AppLanguage.en ? 'Current Order' : (lang == AppLanguage.fr ? 'Commande Actuelle' : 'الطلب الحالي');
    if (key == 'cart_empty') return lang == AppLanguage.en ? 'Cart is empty' : (lang == AppLanguage.fr ? 'Panier vide' : 'السلة فارغة');
    if (key == 'subtotal') return lang == AppLanguage.en ? 'Subtotal' : (lang == AppLanguage.fr ? 'Sous-total' : 'المجموع الفرعي');
    if (key == 'total') return lang == AppLanguage.en ? 'Total' : (lang == AppLanguage.fr ? 'Total' : 'المجموع');
    if (key == 'hold_order') return lang == AppLanguage.en ? 'PRINT & HOLD' : (lang == AppLanguage.fr ? 'IMPRIMER & ATTENTE' : 'طباعة وتعليق');
    if (key == 'undo_last_order') return lang == AppLanguage.en ? 'UNDO LAST ORDER' : (lang == AppLanguage.fr ? 'ANNULER DERNIER' : 'تراجع عن آخر طلب');
    if (key == 'place_order') return lang == AppLanguage.en ? 'PLACE ORDER' : (lang == AppLanguage.fr ? 'COMMANDER' : 'إتمام الطلب');
    return key;
  }

  Future<void> _handleHoldOrder() async {
    final items = ref.read(orderProvider).items;
    if (items.isEmpty || _isProcessingHold) return;

    setState(() => _isProcessingHold = true);
    try {
      final authState = ref.read(authProvider);
      final cashierId = authState.currentUser?.id ?? 1;
      final lang = ref.read(languageProvider);

      final notifier = ref.read(orderProvider.notifier);
      final prepared = notifier.prepareOrder(cashierId: cashierId); 
      if (prepared != null) {
         final pendingOrder = prepared.order.copyWith(
           status: OrderStatus.pending,
           tableName: widget.tableName,
         );
         
         final repo = ref.read(orderRepositoryProvider);
         
         final resumedId = ref.read(orderProvider).resumedOrderId;
         if (resumedId != null) {
           await repo.deleteOrder(resumedId);
         }

         final result = await repo.createOrder(pendingOrder, prepared.items);
         if (result.isSuccess) {
           ref.read(orderProvider.notifier).clearOrder();
           widget.onOrderSuccess();
           
           final settings = await ref.read(appSettingsRepositoryProvider).getSettings() ?? const AppSettings();
           ref.read(orderProvider.notifier).refreshQueueNumber();
           String holdMsg = lang == AppLanguage.en 
               ? 'Printing Kitchen Receipt & Holding Order...' 
               : 'Impression Cuisine & Mise en Attente...';
           
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text("🖨️ $holdMsg"),
                 backgroundColor: const Color(0xFF1E293B),
               ),
             );

             ReceiptHelper.showReceiptPreview(
               context: context,
               order: result.value,
               items: prepared.items,
               settings: settings,
               lang: lang,
               isKitchen: true,
             );
           }
         } else {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text("❌ Hold Failed: ${result.error}"),
                 backgroundColor: Colors.red,
                 duration: const Duration(seconds: 5),
               ),
             );
           }
         }
         ref.invalidate(pendingOrdersProvider);
      }
    } catch (e) {
      debugPrint("Hold Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessingHold = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(orderProvider.select((s) => s.items));
    final subtotal = ref.watch(orderProvider.select((s) => s.subtotalCents));
    final lastId = ref.watch(orderProvider.select((s) => s.lastOrderId));
    final lang = ref.watch(languageProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(25.0),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 28),
              const SizedBox(width: 15),
              Text(_t('current_order', lang), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty 
            ? Center(child: Text(_t('cart_empty', lang), style: TextStyle(color: Colors.grey.shade400)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (item.addons.isNotEmpty)
                                Text(item.addons.map((a) => a.name).join(", "), style: const TextStyle(color: Colors.orange, fontSize: 12)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _qtyBtn(Icons.remove, () => ref.read(orderProvider.notifier).decreaseQty(item)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            _qtyBtn(Icons.add, () => ref.read(orderProvider.notifier).addProduct(item.product, addons: item.addons)),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Text(CurrencyHelper.format((item.product.priceCents + item.addons.fold<int>(0, (sum, a) => sum + a.priceCents)) * item.quantity), 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
        ),
        // SUMMARY SECTION
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_t("subtotal", lang), style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  Text(CurrencyHelper.format(subtotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_t("total", lang), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  Text(CurrencyHelper.format(subtotal), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 20),
              // HOLD BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined),
                  label: Text(_t("hold_order", lang)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFF1E293B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: (items.isEmpty || _isProcessingHold) ? null : _handleHoldOrder,
                ),
              ),
              if (items.isEmpty && lastId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.undo, color: Colors.red),
                    label: Text(_t("undo_last_order", lang), style: const TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () => ref.read(orderProvider.notifier).undoLastOrder(ref, ref.read(productProvider)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // PLACE ORDER BUTTON
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  onPressed: subtotal > 0 ? () => widget.onPlaceOrder(subtotal) : null,
                  child: Text(_t("place_order", lang), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: Icon(icon, size: 16),
      ),
    );
  }
}


class ProductGrid extends ConsumerWidget {
  final int categoryId;
  const ProductGrid({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ ONLY listen to products of this category
    final products = ref.watch(categoryProductsProvider(categoryId));
    
    if (products.isEmpty) {
      return const Center(child: Text("No products found in this category", style: TextStyle(color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, 
        childAspectRatio: 0.8, // Matches Admin Grid
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final bool isOutOfStock = p.trackStock && p.stockQuantity <= 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isOutOfStock ? null : () {
              if (p.addons.isNotEmpty) {
                final state = context.findAncestorStateOfType<_OrderScreenState>();
                state?._showModifierPopup(p); 
              } else {
                ref.read(orderProvider.notifier).addProduct(p);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- 1. IMAGE AREA (Cover) ---
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              image: p.imagePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(p.imagePath!)), 
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: p.imagePath == null
                                ? const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey))
                                : null,
                          ),
                        ),
                        
                        // --- 2. INFO AREA (Admin Style) ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 38, // Enough height for 2 lines if needed
                                child: Text(
                                  p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 15,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyHelper.format(p.priceCents),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // --- OUT OF STOCK OVERLAY ---
                    if (isOutOfStock) ...[
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withOpacity(0.7),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "OUT OF STOCK",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

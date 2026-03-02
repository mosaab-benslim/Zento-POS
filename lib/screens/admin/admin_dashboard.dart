import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/core/providers/language_provider.dart'; // ✅ Corrected path
import 'package:zento_pos/enums/app_language.dart';
import 'package:zento_pos/screens/auth/login_screen.dart'; // ✅ Re-added for logout
import 'package:zento_pos/screens/admin/categories/category_list_screen.dart';
import 'package:zento_pos/screens/admin/products/product_list_screen.dart';
import 'package:zento_pos/screens/admin/staff/staff_list_screen.dart';
import 'package:zento_pos/screens/admin/reports/reports_screen.dart';
import 'package:zento_pos/screens/admin/settings/settings_screen.dart';
import 'package:zento_pos/screens/admin/orders/order_history_screen.dart'; 
import 'package:zento_pos/screens/admin/shifts/shift_history_screen.dart';
import 'package:zento_pos/screens/inventory_screen.dart'; 
import 'package:zento_pos/screens/admin/inventory/stock_receiving_screen.dart';
import 'package:zento_pos/screens/admin/inventory/stock_history_screen.dart';
import 'package:zento_pos/screens/admin/orders/kitchen_orders_screen.dart'; // ✅ Added
import 'package:zento_pos/screens/admin/expenses/expense_list_screen.dart';
import 'package:zento_pos/core/providers/auth_provider.dart';
import 'package:zento_pos/core/providers/ingredient_provider.dart';
import 'package:zento_pos/core/constants/translations.dart';
import 'package:zento_pos/screens/admin/dashboard/widgets/owner_snapshot.dart';
import 'package:zento_pos/screens/admin/tables/tables_screen.dart';

class AdminColors {
  static const Color primary = Color(0xFF2C3E50);
  static const Color accent = Color(0xFF3498DB);
  static const Color bg = Color(0xFFF4F6F8);
}

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  String _t(WidgetRef ref, String key) {
    return AppTranslations.t(ref.watch(languageProvider), key);
  }

  void _cycleLanguage(WidgetRef ref) {
    final current = ref.read(languageProvider);
    final next = current == AppLanguage.en
        ? AppLanguage.fr
        : current == AppLanguage.fr
            ? AppLanguage.ar
            : AppLanguage.en;
    ref.read(languageProvider.notifier).setLanguage(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // Define menu items using the translation helper _t()
    final List<DashboardItem> menuItems = [
      if (auth.isAdmin) ...[
        DashboardItem(
          title: _t(ref, 'menu_products'),
          subtitle: _t(ref, 'sub_products'),
          icon: Icons.inventory_2_outlined,
          color: Colors.blue.shade700,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
          },
        ),
        DashboardItem(
          title: _t(ref, 'menu_categories'),
          subtitle: _t(ref, 'sub_categories'),
          icon: Icons.category_outlined,
          color: Colors.teal.shade600,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryListScreen()));
          },
        ),
      ],
      DashboardItem(
        title: _t(ref, 'menu_history'),
        subtitle: _t(ref, 'sub_history'),
        icon: Icons.history_rounded,
        color: Colors.orange.shade700,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
        },
      ),
      if (auth.isAdmin)
        DashboardItem(
          title: _t(ref, 'menu_staff'),
          subtitle: _t(ref, 'sub_staff'),
          icon: Icons.people_alt_outlined,
          color: Colors.purple.shade600,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListScreen()));
          },
        ),
      if (auth.isAdmin)
        DashboardItem(
          title: _t(ref, 'menu_shifts'),
          subtitle: _t(ref, 'sub_shifts'),
          icon: Icons.assignment_turned_in_outlined,
          color: Colors.indigo.shade700,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ShiftHistoryScreen()));
          },
        ),
      if (auth.isAdmin)
        DashboardItem(
          title: _t(ref, 'menu_reports'),
          subtitle: _t(ref, 'sub_reports'),
          icon: Icons.bar_chart_rounded,
          color: Colors.green.shade700,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
          },
        ),
        DashboardItem(
          title: _t(ref, 'menu_tables'),
          subtitle: _t(ref, 'sub_tables'),
          icon: Icons.table_restaurant,
          color: Colors.brown.shade400,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => TablesScreen()));
          },
        ),
        DashboardItem(
          title: _t(ref, 'menu_expenses'),
          subtitle: _t(ref, 'sub_expenses'),
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.red.shade700,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseListScreen()));
          },
        ),
        DashboardItem(
          title: _t(ref, 'menu_inventory'),
          subtitle: _t(ref, 'sub_inventory'),
          icon: Icons.warehouse_rounded,
          color: Colors.brown.shade700,
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (ctx) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.dashboard_outlined),
                    title: Text(_t(ref, 'inventory_dash')),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_check),
                    title: Text(_t(ref, 'stock_rec')),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StockReceivingScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_edu),
                    title: Text(_t(ref, 'title_stock_history')),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StockHistoryScreen()));
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
        DashboardItem(
          title: _t(ref, 'menu_settings'),
          subtitle: _t(ref, 'sub_settings'),
          icon: Icons.settings_outlined,
          color: Colors.blueGrey.shade600,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          },
        ),
    ];

    return Scaffold(
      backgroundColor: AdminColors.bg,
      appBar: _buildAppBar(context, ref),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOwnerDashboard(context, ref),
            const SizedBox(height: 32),
            Text(
              _t(ref, auth.isAdmin ? 'dashboard_title' : 'manager_dashboard_title'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AdminColors.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(ref, 'dashboard_subtitle'),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth > 1200) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth > 800) {
                  crossAxisCount = 3;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: menuItems.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.3,
                  ),
                  itemBuilder: (context, index) {
                    return _DashboardCard(item: menuItems[index]);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerDashboard(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isAdmin) return const SizedBox.shrink();
    return const OwnerSnapshot();
  }

  AppBar _buildAppBar(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(languageProvider);
    
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 24,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AdminColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.admin_panel_settings, color: AdminColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            _t(ref, ref.watch(authProvider).isAdmin ? 'panel_title' : 'manager_panel_title'),
            style: const TextStyle(color: AdminColors.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        // ✅ Language Toggle Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextButton.icon(
            onPressed: () => _cycleLanguage(ref),
            icon: const Icon(Icons.language, color: AdminColors.primary),
            label: Text(
              currentLang.label, // Uses the getter from language_provider.dart
              style: const TextStyle(color: AdminColors.primary, fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: Colors.grey.shade100,
            ),
          ),
        ),

        // Logout Button
        Padding(
          padding: const EdgeInsets.only(right: 24.0, left: 8.0),
          child: TextButton.icon(
            onPressed: () {
              // 🔥 Clear session
              ref.read(authProvider.notifier).logout();
              
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: Text(_t(ref, 'logout'), style: const TextStyle(color: Colors.redAccent)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: Colors.red.shade50,
            ),
          ),
        )
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.shade200, height: 1),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS & MODELS
// -----------------------------------------------------------------------------

class DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _DashboardCard extends StatefulWidget {
  final DashboardItem item;

  const _DashboardCard({required this.item});

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? widget.item.color.withOpacity(0.5) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.1 : 0.05),
                blurRadius: _isHovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.item.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.item.icon,
                    size: 32,
                    color: widget.item.color,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.item.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

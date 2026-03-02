import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zento_pos/core/models/order_model.dart';
import 'package:zento_pos/core/models/order_item_model.dart';
import 'package:zento_pos/core/repositories/order_repository.dart';
import 'package:zento_pos/core/repositories/app_settings_repository.dart';
import 'package:zento_pos/core/models/app_settings_model.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/core/utils/receipt_helper.dart';
import 'package:zento_pos/main.dart';

final kitchenOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  // We fetch all orders and filter for those not yet completed/voided
  final allOrders = await repo.getAllOrders();
  
  // Filter for active kitchen orders (Pending, Preparing, Ready)
  final activeOrders = allOrders.where((o) => 
    o.status == OrderStatus.pending || 
    o.status == OrderStatus.preparing || 
    o.status == OrderStatus.ready
  ).toList();

  // Sorting Logic (FIFO within Status Groups)
  // Priority: Pending (0) > Preparing (1) > Ready (2)
  // Within groups: Oldest First (at the top)
  activeOrders.sort((a, b) {
    // 1. Sort by Status Hierarchy
    final statusWeight = {
      OrderStatus.pending: 0,
      OrderStatus.preparing: 1,
      OrderStatus.ready: 2,
    };
    
    int cmp = statusWeight[a.status]!.compareTo(statusWeight[b.status]!);
    if (cmp != 0) return cmp;

    // 2. Sort by Time (Oldest First)
    return a.createdAt.compareTo(b.createdAt);
  });

  return activeOrders;
});

class KitchenOrdersScreen extends ConsumerWidget {
  const KitchenOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(kitchenOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Kitchen Queue", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(kitchenOrdersProvider),
          ),
        ],
      ),
      body: ordersAsync.when(
        data: (orders) => orders.isEmpty 
            ? _buildEmptyState() 
            : _buildOrderGrid(context, ref, orders),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No active orders found", style: TextStyle(color: Colors.grey.shade600, fontSize: 18)),
          const Text("New orders will appear here automatically", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildOrderGrid(BuildContext context, WidgetRef ref, List<OrderModel> orders) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisExtent: 320,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) => _OrderKitchenCard(order: orders[index]),
    );
  }
}

class _OrderKitchenCard extends ConsumerWidget {
  final OrderModel order;
  const _OrderKitchenCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor(order.status);
    final timeAgo = DateTime.now().difference(order.createdAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: statusColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("#${order.queueNumber.toString().padLeft(3, '0')}", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                Text("${timeAgo.inMinutes}m ago", 
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.table_restaurant, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(order.tableName ?? "WALK-IN", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      _StatusBadge(status: order.status),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: FutureBuilder<List<OrderItem>>(
                      future: ref.read(orderRepositoryProvider).getOrderItems(order.id!),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final items = snapshot.data!;
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, i) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${items[i].quantity}x ${items[i].productName.toUpperCase()}", 
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              if (items[i].modifiers != null)
                                Text("+ ${items[i].modifiers}", 
                                  style: TextStyle(color: Colors.blue.shade900, fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.print, color: Colors.grey),
                  onPressed: () => _reprintKOT(context, ref),
                ),
                const Spacer(),
                if (order.status == OrderStatus.pending)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    onPressed: () => _updateStatus(ref, OrderStatus.preparing),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("PREPARING"),
                  ),
                if (order.status == OrderStatus.preparing)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () => _updateStatus(ref, OrderStatus.ready),
                    icon: const Icon(Icons.check),
                    label: const Text("READY"),
                  ),
                if (order.status == OrderStatus.ready)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _updateStatus(ref, OrderStatus.completed),
                    icon: const Icon(Icons.done_all),
                    label: const Text("DONE (Archive)"),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return Colors.blueGrey;
      case OrderStatus.preparing: return Colors.orange;
      case OrderStatus.ready: return Colors.green;
      default: return Colors.grey;
    }
  }

  Future<void> _updateStatus(WidgetRef ref, OrderStatus newStatus) async {
    final repo = ref.read(orderRepositoryProvider);
    await repo.updateOrderStatus(order.id!, newStatus);
    ref.invalidate(kitchenOrdersProvider);
  }

  Future<void> _reprintKOT(BuildContext context, WidgetRef ref) async {
    final items = await ref.read(orderRepositoryProvider).getOrderItems(order.id!);
    final settings = await ref.read(appSettingsRepositoryProvider).getSettings() ?? AppSettings();
    
    if (context.mounted) {
      final lang = ref.read(languageProvider);
      await ReceiptHelper.showReceiptPreview(
        context: context,
        order: order,
        items: items,
        settings: settings,
        lang: lang,
        isKitchen: true,
      );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String label = status.name.toUpperCase();
    Color color = Colors.grey;
    if (status == OrderStatus.pending) color = Colors.blueGrey;
    if (status == OrderStatus.preparing) color = Colors.orange;
    if (status == OrderStatus.ready) color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

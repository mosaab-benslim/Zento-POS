import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/order_model.dart';
import '../../../core/repositories/order_repository.dart';
import '../../../main.dart';
import '../../../enums/app_language.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/currency_helper.dart'; 

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final repo = ref.read(orderRepositoryProvider);
    final orders = await repo.getHistoricalOrders();
    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    }
  }

  String _t(String key) {
    final lang = ref.watch(languageProvider);
    final text = {
      'history_title': {AppLanguage.en: 'Order History', AppLanguage.fr: 'Historique', AppLanguage.ar: 'سجل الطلبات'},
      'no_orders': {AppLanguage.en: 'No orders found', AppLanguage.fr: 'Aucune commande', AppLanguage.ar: 'لا توجد طلبات'},
      'refund': {AppLanguage.en: 'Refund', AppLanguage.fr: 'Rembourser', AppLanguage.ar: 'استرجاع'},
      'refund_confirm': {AppLanguage.en: 'Void this order?', AppLanguage.fr: 'Annuler cette commande?', AppLanguage.ar: 'إلغاء الطلب؟'},
      'cancel': {AppLanguage.en: 'Cancel', AppLanguage.fr: 'Annuler', AppLanguage.ar: 'إلغاء'},
      'voided': {AppLanguage.en: 'Voided', AppLanguage.fr: 'Annulé', AppLanguage.ar: 'ملغي'},
    };
    return text[key]?[lang] ?? key;
  }

  void _voidOrder(int orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('refund')),
        content: Text(_t('refund_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(_t('refund'), style: const TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(orderRepositoryProvider);
      final result = await repo.voidOrder(orderId);
      if (result.isSuccess) {
        _loadOrders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('history_title')),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(child: Text(_t('no_orders')))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final date = order.createdAt; // Use createdAt
                    final isVoided = order.status == OrderStatus.voided;

                    return ListTile(
                      title: Text("Order #${order.queueNumber.toString().padLeft(3, '0')} - ${DateFormat('HH:mm:ss').format(date)}"),
                      subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyHelper.format(order.totalCents), 
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isVoided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (isVoided)
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                               child: Text(_t('voided'), style: const TextStyle(color: Colors.red, fontSize: 12)),
                             )
                          else
                            IconButton(
                              icon: const Icon(Icons.undo, color: Colors.red),
                              onPressed: () => _voidOrder(order.id!),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

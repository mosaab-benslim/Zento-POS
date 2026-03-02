import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/translations.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/repositories/expense_repository.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../core/providers/shift_provider.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await ref.read(expenseRepositoryProvider).getExpenses();
    if (mounted) {
      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    }
  }

  String _t(String key) {
    final lang = ref.watch(languageProvider);
    return AppTranslations.data[key]?[lang] ?? key;
  }

  void _showAddExpenseDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'cat_other';
    bool wasPaidFromDrawer = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('lbl_new_expense')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: _t('lbl_description')),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _t('lbl_amount'), prefixText: 'DZD '),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(labelText: _t('lbl_category')),
                items: ['cat_rent', 'cat_salaries', 'cat_utilities', 'cat_other']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(_t(cat))))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedCategory = val!),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(_t('lbl_paid_from_drawer')),
                value: wasPaidFromDrawer,
                onChanged: (val) => setDialogState(() => wasPaidFromDrawer = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('btn_cancel'))),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0 && descriptionController.text.isNotEmpty) {
                  int? shiftId;
                  if (wasPaidFromDrawer) {
                    final activeShift = ref.read(shiftProvider).activeShift;
                    shiftId = activeShift?.id;
                  }

                  final expense = Expense(
                    description: descriptionController.text,
                    amount: amount,
                    category: selectedCategory,
                    timestamp: DateTime.now(),
                    shiftId: shiftId,
                    wasPaidFromDrawer: wasPaidFromDrawer,
                  );
                  await ref.read(expenseRepositoryProvider).saveExpense(expense);
                  Navigator.pop(context);
                  _loadExpenses();
                }
              },
              child: Text(_t('btn_save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('menu_expenses')),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddExpenseDialog),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        _t('msg_no_expenses'),
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final exp = _expenses[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.upload_rounded, color: Colors.red, size: 24),
                        ),
                        title: Text(
                          exp.description,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              "${_t(exp.category)} • ${DateFormat('yyyy-MM-dd HH:mm').format(exp.timestamp)}",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            if (exp.wasPaidFromDrawer)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _t('lbl_paid_from_drawer'),
                                  style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        trailing: Text(
                          "DZD ${exp.amount.toStringAsFixed(0)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900, 
                            fontSize: 18, 
                            color: Colors.red,
                          ),
                        ),
                        onLongPress: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(_t('btn_delete')),
                              content: Text(_t('msg_delete_confirm')),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('btn_cancel'))),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true), 
                                  child: Text(_t('btn_delete'), style: const TextStyle(color: Colors.red))
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(expenseRepositoryProvider).deleteExpense(exp.id!);
                            _loadExpenses();
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

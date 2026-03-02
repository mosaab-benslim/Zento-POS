import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zento_pos/main.dart'; 
import 'package:zento_pos/core/models/table_model.dart';
import 'package:zento_pos/core/models/order_model.dart';
import 'package:zento_pos/core/repositories/order_repository.dart';
import 'package:zento_pos/core/providers/language_provider.dart';
import 'package:zento_pos/enums/app_language.dart';

class TableSelectionDialog extends ConsumerStatefulWidget {
  const TableSelectionDialog({super.key});

  @override
  ConsumerState<TableSelectionDialog> createState() => _TableSelectionDialogState();
}

class _TableSelectionDialogState extends ConsumerState<TableSelectionDialog> {
  List<TableModel> _tables = [];
  Set<String> _occupiedTableNames = {}; // ✅ Track busy tables
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    final tableRepo = ref.read(tableRepositoryProvider);
    final orderRepo = ref.read(orderRepositoryProvider);
    
    // 1. Fetch tables
    final tables = await tableRepo.getAllTables();
    
    // 2. Fetch pending orders to see which tables are busy
    final List<OrderModel> pendingOrders = await orderRepo.getPendingOrders();
    final Set<String> busyTables = pendingOrders
        .where((o) => o.tableName != null)
        .map((o) => o.tableName!)
        .toSet();

    if (mounted) {
      setState(() {
        _tables = tables.where((t) => t.isActive).toList(); // Only show active
        _occupiedTableNames = busyTables;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final isRtl = language == AppLanguage.ar;

    // --- DIALOG TRANSLATIONS ---
    String tHeader = language == AppLanguage.en ? "Select Table" : (language == AppLanguage.fr ? "Choisir Table" : "إختيار طاولة");
    String tSub = language == AppLanguage.en 
        ? "Choose an available table" 
        : (language == AppLanguage.fr ? "Choisissez une table disponible" : "اختر طاولة متاحة");
    String tOccupied = language == AppLanguage.en ? "OCCUPIED" : (language == AppLanguage.fr ? "OCCUPÉE" : "مشغولة");
    String tAvailable = language == AppLanguage.en ? "AVAILABLE" : (language == AppLanguage.fr ? "DISPONIBLE" : "متاحة");
    String tNoTables = language == AppLanguage.en ? "No tables found" : (language == AppLanguage.fr ? "Aucune table" : "لا يوجد طاولات");
    String tBusyMsg = language == AppLanguage.en 
        ? "is already busy" 
        : (language == AppLanguage.fr ? "est déjà occupée" : "مشغولة بالفعل");

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Container(
          width: 700,
          height: 600,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            children: [
              // --- HEADER ---
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.table_restaurant_rounded, color: Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tHeader,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            tSub,
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 20, color: Colors.grey),
                      ),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // --- GRID ---
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tables.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.table_bar_outlined, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(tNoTables, style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(32),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: _tables.length,
                            itemBuilder: (context, index) {
                              final table = _tables[index];
                              final isOccupied = _occupiedTableNames.contains(table.name);

                              return InkWell(
                                onTap: () {
                                  if (isOccupied) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("${table.name} $tBusyMsg."),
                                        backgroundColor: Colors.orange.shade800,
                                        behavior: SnackBarBehavior.floating,
                                        width: 300,
                                      ),
                                    );
                                  }
                                  Navigator.pop(context, table);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isOccupied ? Colors.red.withOpacity(0.03) : Colors.green.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isOccupied ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isOccupied ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.table_bar_rounded, 
                                          size: 28, 
                                          color: isOccupied ? Colors.red : Colors.green
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        table.name,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: isOccupied ? const Color(0xFF991B1B) : const Color(0xFF166534),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isOccupied ? Colors.red.shade100 : Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isOccupied ? tOccupied : tAvailable,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isOccupied ? Colors.red.shade800 : Colors.green.shade800,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import '../models/table_model.dart';

abstract class TableRepository {
  Future<List<TableModel>> getAllTables();
  Future<void> addTable(TableModel table);
  Future<void> updateTable(TableModel table);
  Future<void> deleteTable(int id);
}

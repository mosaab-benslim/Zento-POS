import 'package:sqflite/sqflite.dart';
import '../models/table_model.dart';
import 'app_database.dart';

class TableDao {
  final dbProvider = AppDatabase.instance;

  Future<int> insertTable(TableModel table) async {
    final db = await dbProvider.database;
    return await db.insert('tables', table.toMap());
  }

  Future<void> updateTable(TableModel table) async {
    final db = await dbProvider.database;
    await db.update(
      'tables',
      table.toMap(),
      where: 'id = ?',
      whereArgs: [table.id],
    );
  }

  Future<void> deleteTable(int id) async {
    final db = await dbProvider.database;
    // Logical delete? Or physical? Plan said "delete", let's do soft delete via is_active or hard delete.
    // Plan implied CRUD, usually physical delete is fine for tables if no orders linked, but foreign keys...
    // Current orders table doesn't have FK to tables (it uses text tableName). So hard delete is safe.
    await db.delete('tables', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TableModel>> getAllTables() async {
    final db = await dbProvider.database;
    final result = await db.query('tables', orderBy: 'id ASC');
    return result.map((json) => TableModel.fromMap(json)).toList();
  }
}

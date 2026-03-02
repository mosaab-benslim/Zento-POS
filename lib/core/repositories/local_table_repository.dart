import '../database/table_dao.dart';
import '../models/table_model.dart';
import 'table_repository.dart';

class LocalTableRepository implements TableRepository {
  final TableDao _tableDao;

  LocalTableRepository(this._tableDao);

  @override
  Future<List<TableModel>> getAllTables() async {
    return await _tableDao.getAllTables();
  }

  @override
  Future<void> addTable(TableModel table) async {
    await _tableDao.insertTable(table);
  }

  @override
  Future<void> updateTable(TableModel table) async {
    await _tableDao.updateTable(table);
  }

  @override
  Future<void> deleteTable(int id) async {
    await _tableDao.deleteTable(id);
  }
}

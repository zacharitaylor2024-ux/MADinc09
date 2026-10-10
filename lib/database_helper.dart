import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'schema.dart';

class DatabaseHelper {
  // Preserve the Part I database path/table/columns exactly.
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';
  late Database _db;

  Database get database => _db;

  Future<void> init() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: Activity09Schema.configure,
      onCreate: _onCreate,
      onUpgrade: Activity09Schema.upgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Fresh installs need BOTH the historical table and the new tables.
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');
    await Activity09Schema.createNewTables(db);
  }

  // Original Part I CRUD is intentionally preserved.
  Future<int> insert(Map<String, dynamic> row) async => _db.insert(table, row);
  Future<List<Map<String, dynamic>>> queryAllRows() async => _db.query(table);
  Future<int> queryRowCount() async {
    final results = await _db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(results) ?? 0;
  }
  Future<int> update(Map<String, dynamic> row) async {
    final int id = row[columnId] as int;
    return _db.update(table, row, where: '$columnId = ?', whereArgs: [id]);
  }
  Future<int> delete(int id) async =>
      _db.delete(table, where: '$columnId = ?', whereArgs: [id]);
}

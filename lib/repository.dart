import 'package:sqflite/sqflite.dart';
import 'models.dart';

/// Pass your EXISTING Part I database getter, not a new database filename.
class CardRepository {
  final Future<Database> Function() openExistingDatabase;
  const CardRepository(this.openExistingDatabase);

  Future<List<CardFolder>> getFoldersWithCounts() async {
    final db = await openExistingDatabase();
    final rows = await db.rawQuery('''
      SELECT f.id, f.name, f.created_at, COUNT(c.id) AS card_count
      FROM folders AS f LEFT JOIN cards AS c ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.created_at
      ORDER BY f.name COLLATE NOCASE ASC
    ''');
    return rows.map(CardFolder.fromMap).toList();
  }

  Future<List<PlayingCard>> getCards(int folderId) async {
    final db = await openExistingDatabase();
    final rows = await db.query('cards', where: 'folder_id = ?',
        whereArgs: [folderId], orderBy: 'title COLLATE NOCASE ASC, id ASC');
    return rows.map(PlayingCard.fromMap).toList();
  }

  Future<bool> folderExists(int folderId) async {
    final db = await openExistingDatabase();
    final rows = await db.query('folders', columns: ['id'],
        where: 'id = ?', whereArgs: [folderId], limit: 1);
    return rows.isNotEmpty;
  }

  Future<int> insertFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Folder name is required');
    final db = await openExistingDatabase();
    return db.insert('folders', CardFolder(
      name: trimmed, createdAt: DateTime.now().toUtc().toIso8601String(),
    ).toMap());
  }

  Future<int> updateFolder(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Folder name is required');
    final db = await openExistingDatabase();
    return db.update('folders', {'name': trimmed}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteFolder(int id) async {
    final db = await openExistingDatabase();
    return db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _validateCard(PlayingCard card) async {
    if (card.title.trim().isEmpty) throw ArgumentError('Card title is required');
    if (!PlayingCard.suits.contains(card.suit)) throw ArgumentError('Invalid suit');
    if (!await folderExists(card.folderId)) throw ArgumentError('Select an existing folder');
  }

  Future<int> insertCard(PlayingCard card) async {
    await _validateCard(card);
    final db = await openExistingDatabase();
    return db.insert('cards', card.toMap());
  }

  Future<int> updateCard(int id, PlayingCard card) async {
    await _validateCard(card);
    final db = await openExistingDatabase();
    return db.update('cards', card.toMap(), where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCard(int id) async {
    final db = await openExistingDatabase();
    return db.delete('cards', where: 'id = ?', whereArgs: [id]);
  }
}

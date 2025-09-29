import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/nfc_card.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'nfc_cards.db');

    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE nfc_cards(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        uid TEXT NOT NULL UNIQUE,
        technology TEXT NOT NULL,
        data TEXT,
        createdAt TEXT NOT NULL,
        lastUsed TEXT
      )
    ''');
  }

  Future<int> insertCard(NFCCard card) async {
    final db = await database;
    return await db.insert('nfc_cards', card.toMap());
  }

  Future<List<NFCCard>> getAllCards() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'nfc_cards',
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return NFCCard.fromMap(maps[i]);
    });
  }

  Future<List<NFCCard>> searchCards(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'nfc_cards',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return NFCCard.fromMap(maps[i]);
    });
  }

  Future<NFCCard?> getCardByUid(String uid) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'nfc_cards',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    if (maps.isNotEmpty) {
      return NFCCard.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateCard(NFCCard card) async {
    final db = await database;
    return await db.update(
      'nfc_cards',
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteCard(int id) async {
    final db = await database;
    return await db.delete('nfc_cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateLastUsed(int id) async {
    final db = await database;
    return await db.update(
      'nfc_cards',
      {'lastUsed': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}

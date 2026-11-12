import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'personal_finance.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            is_income INTEGER NOT NULL,
            date TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'Інше',
            description TEXT NOT NULL DEFAULT ''
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE transactions "
            "ADD COLUMN category TEXT NOT NULL DEFAULT 'Інше'",
          );

          await db.execute(
            "ALTER TABLE transactions "
            "ADD COLUMN description TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
  }

  Future<int> insertTransaction({
    required String title,
    required double amount,
    required bool isIncome,
    required DateTime date,
    String category = 'Інше',
    String description = '',
  }) async {
    final db = await database;

    return db.insert('transactions', {
      'title': title,
      'amount': amount,
      'is_income': isIncome ? 1 : 0,
      'date': date.toIso8601String(),
      'category': category,
      'description': description,
    });
  }

  Future<List<Map<String, Object?>>> getTransactions() async {
    final db = await database;

    return db.query('transactions', orderBy: 'date DESC, id DESC');
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;

    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateTransaction({
    required int id,
    required String title,
    required double amount,
    required bool isIncome,
    required DateTime date,
    String category = 'Інше',
    String description = '',
  }) async {
    final db = await database;

    return db.update(
      'transactions',
      {
        'title': title,
        'amount': amount,
        'is_income': isIncome ? 1 : 0,
        'date': date.toIso8601String(),
        'category': category,
        'description': description,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

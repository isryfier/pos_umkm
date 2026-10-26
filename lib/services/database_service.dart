import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/menu_model.dart';
import '../models/transaction_model.dart';

/// Dilempar saat stok tidak cukup atau menu sudah dihapus ketika transaksi disimpan.
class StockException implements Exception {
  final String message;
  const StockException(this.message);

  @override
  String toString() => message;
}

/// Pengelola database SQLite lokal.
///
/// Memakai pola singleton: seluruh aplikasi berbagi satu koneksi database
/// lewat `DatabaseService.instance`.
class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService instance = DatabaseService._internal();

  static Database? _db;

  static const String _dbName = 'pos_kuliner.db';
  static const String _tableMenu = 'menu';
  static const String _tableTrx = 'transactions';
  static const String _tableTrxItem = 'transaction_items';

  /// Versi 1 = tabel menu (Sesi 2A). Versi 2 = tambah tabel transaksi (Sesi 2B).
  static const int _dbVersion = 2;

  /// Mengambil koneksi database. Dibuat otomatis saat pertama kali dipakai.
  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      // Instalasi baru: buat semua tabel.
      onCreate: (db, version) async {
        await _createMenuTable(db);
        await _createTransactionTables(db);
      },
      // Pengguna lama (versi 1): tambah tabel transaksi, data menu tetap aman.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTransactionTables(db);
        }
      },
    );
  }

  Future<void> _createMenuTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableMenu (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        category TEXT NOT NULL,
        stock INTEGER NOT NULL,
        isAvailable INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _createTransactionTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableTrx (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNo TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        cashierName TEXT NOT NULL,
        total INTEGER NOT NULL,
        paidAmount INTEGER NOT NULL,
        changeAmount INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $_tableTrxItem (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId INTEGER NOT NULL,
        menuId INTEGER NOT NULL,
        menuName TEXT NOT NULL,
        price INTEGER NOT NULL,
        qty INTEGER NOT NULL
      )
    ''');
  }

  // ---------------------------------------------------------------------------
  // MENU
  // ---------------------------------------------------------------------------

  /// Menambah menu baru. Mengembalikan ID menu yang dibuat.
  Future<int> insertMenu(MenuModel menu) async {
    final db = await database;
    return db.insert(_tableMenu, menu.toMap());
  }

  /// Mengambil semua menu, diurutkan berdasarkan nama.
  /// Isi [category] untuk memfilter hanya makanan atau hanya minuman.
  Future<List<MenuModel>> getAllMenu({MenuCategory? category}) async {
    final db = await database;
    final rows = await db.query(
      _tableMenu,
      where: category == null ? null : 'category = ?',
      whereArgs: category == null ? null : [category.name],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(MenuModel.fromMap).toList();
  }

  /// Memperbarui seluruh data satu menu (nama, harga, kategori, stok, dll).
  Future<int> updateMenu(MenuModel menu) async {
    final db = await database;
    return db.update(
      _tableMenu,
      menu.toMap(),
      where: 'id = ?',
      whereArgs: [menu.id],
    );
  }

  /// Memperbarui stok saja (dipakai untuk tombol +/- stok cepat).
  Future<int> updateStock(int id, int newStock) async {
    final db = await database;
    return db.update(
      _tableMenu,
      {'stock': newStock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Menghapus satu menu berdasarkan ID.
  Future<int> deleteMenu(int id) async {
    final db = await database;
    return db.delete(_tableMenu, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // TRANSAKSI
  // ---------------------------------------------------------------------------

  /// Membuat nomor struk berurutan per hari, contoh: INV-20261026-001.
  Future<String> generateInvoiceNo() async {
    final db = await database;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_tableTrx WHERE createdAt >= ?',
      [dayStart.millisecondsSinceEpoch],
    );
    final count = (Sqflite.firstIntValue(result) ?? 0) + 1;

    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'INV-$y$m$d-${count.toString().padLeft(3, '0')}';
  }

  /// Menyimpan transaksi + item-itemnya, sekaligus mengurangi stok menu.
  ///
  /// Semuanya dalam satu transaksi database: kalau ada yang gagal (misalnya
  /// stok tidak cukup), seluruh perubahan dibatalkan dan [StockException] dilempar.
  /// Mengembalikan ID transaksi yang dibuat.
  Future<int> insertTransaction(TransactionModel trx) async {
    final db = await database;
    return db.transaction((txn) async {
      // 1) Cek stok semua item lebih dulu.
      for (final item in trx.items) {
        final rows = await txn.query(
          _tableMenu,
          columns: ['stock'],
          where: 'id = ?',
          whereArgs: [item.menuId],
        );
        if (rows.isEmpty) {
          throw StockException('Menu "${item.menuName}" sudah dihapus');
        }
        final stock = rows.first['stock'] as int;
        if (stock < item.qty) {
          throw StockException(
              'Stok "${item.menuName}" tinggal $stock, tidak cukup');
        }
      }

      // 2) Simpan transaksi.
      final trxId = await txn.insert(_tableTrx, trx.toMap());

      // 3) Simpan tiap item dan kurangi stoknya.
      for (final item in trx.items) {
        await txn.insert(_tableTrxItem, item.toMap(transactionId: trxId));
        await txn.rawUpdate(
          'UPDATE $_tableMenu SET stock = stock - ? WHERE id = ?',
          [item.qty, item.menuId],
        );
      }
      return trxId;
    });
  }
}

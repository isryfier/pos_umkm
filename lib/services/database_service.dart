import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/menu_model.dart';

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

  /// Mengambil koneksi database. Dibuat otomatis saat pertama kali dipakai.
  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  /// Membuat file database dan tabel `menu` jika belum ada.
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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
      },
    );
  }

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
}

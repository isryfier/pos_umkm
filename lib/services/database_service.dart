import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/menu_model.dart';
import '../models/report_model.dart';
import '../models/transaction_model.dart';
import '../utils/security.dart';

/// Dilempar saat stok tidak cukup atau menu sudah dihapus ketika transaksi disimpan.
class StockException implements Exception {
  final String message;
  const StockException(this.message);

  @override
  String toString() => message;
}

/// Dilempar saat pembatalan (void) transaksi tidak bisa dilakukan,
/// misalnya transaksi tidak ditemukan atau sudah pernah dibatalkan.
class VoidException implements Exception {
  final String message;
  const VoidException(this.message);

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
  static const String _tableUsers = 'users';

  /// Versi 1 = tabel menu (Sesi 2A).
  /// Versi 2 = tambah tabel transaksi (Sesi 2B).
  /// Versi 3 = tambah kolom `status` di transaksi untuk void (Sesi 3A).
  /// Versi 4 = tambah tabel `users` untuk akun owner/kasir (Sesi 5).
  /// Versi 5 = tambah kolom `note` di item transaksi untuk catatan pesanan (Sesi 7).
  static const int _dbVersion = 5;

  /// Versi struktur database saat ini (dipakai untuk memeriksa file backup).
  static const int schemaVersion = _dbVersion;

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
        await _createUserTable(db);
        await _seedOwner(db);
      },
      // Pengguna lama: naikkan versi tanpa menghapus data.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Dari versi 1: tabel transaksi belum ada (sudah lengkap: status & note).
          await _createTransactionTables(db);
        } else {
          if (oldVersion < 3) {
            // Dari versi 2: tabel ada, tapi belum punya kolom status.
            await db.execute(
              "ALTER TABLE $_tableTrx ADD COLUMN status TEXT NOT NULL DEFAULT 'SUCCESS'",
            );
          }
          if (oldVersion < 5) {
            // Dari versi 2-4: tambah kolom catatan pesanan di item transaksi.
            await db.execute(
              'ALTER TABLE $_tableTrxItem ADD COLUMN note TEXT',
            );
          }
        }
        if (oldVersion < 4) {
          // Tabel akun baru + satu akun owner awal. Data lain tidak disentuh.
          await _createUserTable(db);
          await _seedOwner(db);
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
        changeAmount INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'SUCCESS'
      )
    ''');
    await db.execute('''
      CREATE TABLE $_tableTrxItem (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transactionId INTEGER NOT NULL,
        menuId INTEGER NOT NULL,
        menuName TEXT NOT NULL,
        price INTEGER NOT NULL,
        qty INTEGER NOT NULL,
        note TEXT
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
      // 1) Cek stok. Item dengan menu yang sama (tapi catatan berbeda)
      //    dijumlahkan dulu, supaya total pesanan tidak melebihi stok.
      final needed = <int, int>{};
      final names = <int, String>{};
      for (final item in trx.items) {
        needed[item.menuId] = (needed[item.menuId] ?? 0) + item.qty;
        names[item.menuId] = item.menuName;
      }
      for (final entry in needed.entries) {
        final rows = await txn.query(
          _tableMenu,
          columns: ['stock'],
          where: 'id = ?',
          whereArgs: [entry.key],
        );
        if (rows.isEmpty) {
          throw StockException('Menu "${names[entry.key]}" sudah dihapus');
        }
        final stock = rows.first['stock'] as int;
        if (stock < entry.value) {
          throw StockException(
              'Stok "${names[entry.key]}" tinggal $stock, tidak cukup');
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

  /// Mengambil riwayat transaksi, terbaru di atas.
  ///
  /// Isi [day] untuk hanya menampilkan transaksi pada tanggal tersebut.
  /// Setiap transaksi sudah berisi daftar item-nya.
  Future<List<TransactionModel>> getAllTransactions({DateTime? day}) async {
    final db = await database;

    String? where;
    List<Object?>? whereArgs;
    if (day != null) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      where = 'createdAt >= ? AND createdAt < ?';
      whereArgs = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];
    }

    final rows = await db.query(
      _tableTrx,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
    );

    final result = <TransactionModel>[];
    for (final row in rows) {
      final itemRows = await db.query(
        _tableTrxItem,
        where: 'transactionId = ?',
        whereArgs: [row['id']],
      );
      result.add(TransactionModel.fromMap(
        row,
        items: itemRows.map(TransactionItemModel.fromMap).toList(),
      ));
    }
    return result;
  }

  /// Membatalkan (void) transaksi dan mengembalikan stok menu.
  ///
  /// Transaksi tidak dihapus, hanya ditandai 'VOID' agar tetap ada jejaknya.
  /// Transaksi yang sudah VOID tidak bisa dibatalkan lagi, supaya stok
  /// tidak bertambah dua kali. Semua langkah dalam satu transaksi database.
  Future<void> voidTransaction(int transactionId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        _tableTrx,
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [transactionId],
      );
      if (rows.isEmpty) {
        throw const VoidException('Transaksi tidak ditemukan');
      }
      if (rows.first['status'] == 'VOID') {
        throw const VoidException('Transaksi ini sudah dibatalkan');
      }

      final items = await txn.query(
        _tableTrxItem,
        where: 'transactionId = ?',
        whereArgs: [transactionId],
      );

      // Kembalikan stok. Menu yang sudah dihapus dilewati begitu saja.
      for (final item in items) {
        await txn.rawUpdate(
          'UPDATE $_tableMenu SET stock = stock + ? WHERE id = ?',
          [item['qty'], item['menuId']],
        );
      }

      await txn.update(
        _tableTrx,
        {'status': 'VOID'},
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // LAPORAN
  // ---------------------------------------------------------------------------

  /// Menyusun laporan penjualan dari tanggal [from] sampai [to] (keduanya
  /// ikut dihitung penuh, dari jam 00:00 hari pertama sampai akhir hari terakhir).
  /// Transaksi VOID tidak dihitung sebagai penjualan, hanya dihitung jumlahnya.
  Future<SalesReport> getSalesReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day + 1);
    final args = [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch];

    final trxRows = await db.query(
      _tableTrx,
      columns: ['createdAt', 'total', 'status'],
      where: 'createdAt >= ? AND createdAt < ?',
      whereArgs: args,
    );

    // Siapkan semua hari dalam rentang dengan nilai 0: [total, jumlah transaksi].
    final byDay = <DateTime, List<int>>{};
    for (var d = start; d.isBefore(end); d = DateTime(d.year, d.month, d.day + 1)) {
      byDay[d] = [0, 0];
    }

    int totalSales = 0;
    int trxCount = 0;
    int voidCount = 0;
    for (final row in trxRows) {
      if (row['status'] == 'VOID') {
        voidCount++;
        continue;
      }
      final total = row['total'] as int;
      final t = DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int);
      final slot = byDay[DateTime(t.year, t.month, t.day)];
      if (slot != null) {
        slot[0] += total;
        slot[1] += 1;
      }
      totalSales += total;
      trxCount++;
    }

    // Menu terlaris: dijumlahkan dari item transaksi yang tidak di-void.
    final itemRows = await db.rawQuery('''
      SELECT i.menuName AS name,
             SUM(i.qty) AS qty,
             SUM(i.qty * i.price) AS revenue
      FROM $_tableTrxItem i
      JOIN $_tableTrx t ON t.id = i.transactionId
      WHERE t.createdAt >= ? AND t.createdAt < ? AND t.status != 'VOID'
      GROUP BY i.menuId, i.menuName
      ORDER BY qty DESC, revenue DESC
    ''', args);

    int itemsSold = 0;
    final topMenus = <TopMenu>[];
    for (final r in itemRows) {
      final qty = r['qty'] as int;
      itemsSold += qty;
      topMenus.add(TopMenu(
        name: r['name'] as String,
        qty: qty,
        revenue: r['revenue'] as int,
      ));
    }

    return SalesReport(
      totalSales: totalSales,
      trxCount: trxCount,
      voidCount: voidCount,
      itemsSold: itemsSold,
      daily: byDay.entries
          .map((e) => DailySales(
                day: e.key,
                total: e.value[0],
                count: e.value[1],
              ))
          .toList(),
      topMenus: topMenus,
    );
  }

  // ---------------------------------------------------------------------------
  // AKUN PENGGUNA
  // Catatan: nilai password/PIN yang masuk ke sini sudah berupa hash
  // (lihat AuthService dan utils/security.dart).
  // ---------------------------------------------------------------------------

  Future<void> _createUserTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_tableUsers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE COLLATE NOCASE,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        salt TEXT NOT NULL,
        passwordHash TEXT NOT NULL,
        pinHash TEXT
      )
    ''');
  }

  /// Membuat akun owner awal: username `owner`, password `owner123`, PIN `123456`.
  /// Owner wajib mengganti ketiganya lewat menu Kelola Akun setelah login pertama.
  Future<void> _seedOwner(Database db) async {
    final salt = Security.generateSalt();
    await db.insert(_tableUsers, {
      'username': 'owner',
      'name': 'Owner',
      'role': 'owner',
      'salt': salt,
      'passwordHash': Security.hash(salt, 'pw', 'owner123'),
      'pinHash': Security.hash(salt, 'pin', '123456'),
    });
  }

  /// Mencari akun berdasarkan username (tidak peka huruf besar/kecil).
  Future<Map<String, Object?>?> findUser(String username) async {
    final db = await database;
    final rows = await db.query(
      _tableUsers,
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query(
      _tableUsers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Mengambil semua akun dengan peran tertentu ('owner' atau 'staff').
  Future<List<Map<String, Object?>>> getUsersByRole(String role) async {
    final db = await database;
    return db.query(
      _tableUsers,
      where: 'role = ?',
      whereArgs: [role],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  Future<int> insertUser(Map<String, Object?> values) async {
    final db = await database;
    return db.insert(_tableUsers, values);
  }

  Future<int> updateUser(int id, Map<String, Object?> values) async {
    final db = await database;
    return db.update(_tableUsers, values, where: 'id = ?', whereArgs: [id]);
  }

  /// Menghapus akun kasir. Akun owner tidak bisa dihapus lewat fungsi ini.
  /// Riwayat transaksi tetap utuh karena nama kasir tersimpan di setiap transaksi.
  Future<int> deleteStaff(int id) async {
    final db = await database;
    return db.delete(
      _tableUsers,
      where: 'id = ? AND role = ?',
      whereArgs: [id, 'staff'],
    );
  }

  // ---------------------------------------------------------------------------
  // BACKUP & PULIHKAN (dipakai oleh BackupService)
  // ---------------------------------------------------------------------------

  /// Lokasi file database di HP.
  Future<String> databaseFilePath() async {
    return join(await getDatabasesPath(), _dbName);
  }

  /// Menutup koneksi database. Koneksi dibuka lagi otomatis saat dibutuhkan.
  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}

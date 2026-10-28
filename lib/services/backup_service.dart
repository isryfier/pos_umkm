import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

/// Dilempar saat backup atau pemulihan tidak bisa dilakukan.
/// [message] aman ditampilkan langsung ke pengguna.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

/// Membuat dan memulihkan backup. Satu backup = satu salinan utuh file
/// database (menu, transaksi, dan akun), jadi semuanya ikut tersimpan.
class BackupService {
  final _dbService = DatabaseService.instance;

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Membuat file backup di folder sementara, siap dibagikan.
  /// Nama file memuat tanggal & jam, contoh: pos_kuliner_backup_20261028_1530.db
  Future<File> createBackup() async {
    final db = await _dbService.database;

    // Pastikan semua data sudah tertulis ke file utama sebelum disalin.
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {
      // Tidak semua mode database mendukungnya; aman diabaikan.
    }

    final source = await _dbService.databaseFilePath();
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = '${now.year}${_two(now.month)}${_two(now.day)}'
        '_${_two(now.hour)}${_two(now.minute)}';

    return File(source).copy(p.join(dir.path, 'pos_kuliner_backup_$stamp.db'));
  }

  /// Memulihkan data dari file backup di [pickedPath].
  ///
  /// Langkah: periksa file dulu -> simpan salinan pengaman data sekarang ->
  /// ganti database -> buka ulang. Kalau gagal di tengah jalan, data lama
  /// dikembalikan. Setelah berhasil, pengguna harus login ulang karena
  /// daftar akun ikut berganti.
  Future<void> restore(String pickedPath) async {
    final picked = File(pickedPath);
    if (!await picked.exists()) {
      throw const BackupException('File tidak ditemukan');
    }

    // 1) Pastikan ini benar-benar backup POS Kuliner (buka hanya-baca).
    Database? check;
    try {
      check = await openDatabase(pickedPath, readOnly: true);
      final rows = await check
          .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      final tables = rows.map((r) => r['name'] as String).toSet();
      final version = await check.getVersion();

      if (!tables.containsAll({'menu', 'transactions', 'transaction_items'})) {
        throw const BackupException('File ini bukan backup POS Kuliner');
      }
      if (version > DatabaseService.schemaVersion) {
        throw const BackupException(
            'Backup ini dibuat oleh versi aplikasi yang lebih baru. Perbarui aplikasi dulu.');
      }
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('File tidak bisa dibaca sebagai backup');
    } finally {
      await check?.close();
    }

    // 2) Simpan salinan pengaman, lalu ganti database.
    final target = await _dbService.databaseFilePath();
    await _dbService.close();

    final safety = File('$target.sebelum_pulih');
    final current = File(target);
    if (await current.exists()) {
      await current.copy(safety.path);
    }

    try {
      await picked.copy(target);
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final f = File('$target$suffix');
        if (await f.exists()) await f.delete();
      }

      // 3) Buka ulang: menjalankan peningkatan struktur kalau backup lebih lama.
      final db = await _dbService.database;
      await db.rawQuery('SELECT COUNT(*) FROM menu');
    } catch (_) {
      // Gagal: kembalikan data yang lama.
      await _dbService.close();
      if (await safety.exists()) {
        await safety.copy(target);
      }
      throw const BackupException('Pemulihan gagal. Data lama dikembalikan.');
    }
  }
}

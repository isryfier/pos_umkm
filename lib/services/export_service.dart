import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/payment.dart';
import 'database_service.dart';

/// Membuat file CSV penjualan (satu baris per item terjual) untuk dibuka di
/// Excel/Google Sheets atau dianalisis AI.
///
/// Pemisah kolom memakai titik koma (;) supaya langsung rapi di Excel
/// berbahasa Indonesia. Google Sheets juga mengenalinya otomatis.
class ExportService {
  ExportService({DatabaseService? db}) : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  static const _sep = ';';

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Membungkus nilai dengan tanda kutip jika perlu.
  String _cell(Object? v) {
    final s = (v ?? '').toString();
    if (s.contains(_sep) || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Menulis CSV ke folder sementara dan mengembalikan path-nya.
  /// Mengembalikan null jika tidak ada data pada rentang tanggal itu.
  Future<String?> createSalesCsv({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _db.getSalesLines(from: from, to: to);
    if (rows.isEmpty) return null;

    final buf = StringBuffer('﻿'); // BOM agar Excel membaca UTF-8
    buf.writeln([
      'Tanggal',
      'Jam',
      'No Antrian',
      'No Struk',
      'Kasir',
      'Menu',
      'Kategori',
      'Jumlah',
      'Harga Satuan',
      'Subtotal',
      'Catatan',
      'Metode Bayar',
      'Pilihan QRIS',
      'Status',
    ].join(_sep));

    for (final r in rows) {
      final t = DateTime.fromMillisecondsSinceEpoch(r['createdAt'] as int);
      final qty = r['qty'] as int;
      final price = r['price'] as int;
      final q = (r['queueNo'] as int?) ?? 0;
      buf.writeln([
        '${t.year}-${_two(t.month)}-${_two(t.day)}',
        '${_two(t.hour)}:${_two(t.minute)}',
        q <= 0 ? '' : q,
        r['invoiceNo'],
        r['cashier'],
        r['menuName'],
        r['category'] ?? '-',
        qty,
        price,
        qty * price,
        r['note'] ?? '',
        PaymentMethod.label((r['paymentMethod'] as String?) ?? PaymentMethod.cash),
        r['paymentChannel'] ?? '',
        r['status'] == 'VOID' ? 'VOID' : 'Berhasil',
      ].map(_cell).join(_sep));
    }

    final dir = await getTemporaryDirectory();
    String ymd(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';
    final path = '${dir.path}/penjualan_${ymd(from)}_${ymd(to)}.csv';
    await File(path).writeAsString(buf.toString());
    return path;
  }
}

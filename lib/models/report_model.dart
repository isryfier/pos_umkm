/// Penjualan satu menu dalam rentang laporan (untuk daftar "menu terlaris").
class TopMenu {
  final String name;

  /// Jumlah porsi terjual.
  final int qty;

  /// Total uang dari menu ini (harga x jumlah).
  final int revenue;

  const TopMenu({
    required this.name,
    required this.qty,
    required this.revenue,
  });
}

/// Penjualan satu hari.
class DailySales {
  final DateTime day;

  /// Total penjualan hari itu (tidak termasuk transaksi VOID).
  final int total;

  /// Jumlah transaksi berhasil hari itu.
  final int count;

  const DailySales({
    required this.day,
    required this.total,
    required this.count,
  });
}

/// Ringkasan laporan penjualan untuk satu rentang tanggal.
/// Transaksi VOID tidak dihitung sebagai penjualan.
class SalesReport {
  /// Total omzet.
  final int totalSales;

  /// Jumlah transaksi berhasil.
  final int trxCount;

  /// Jumlah transaksi yang dibatalkan (VOID).
  final int voidCount;

  /// Total porsi/item yang terjual.
  final int itemsSold;

  /// Penjualan per hari, urut dari tanggal awal ke akhir.
  final List<DailySales> daily;

  /// Menu terlaris, urut dari yang paling banyak terjual.
  final List<TopMenu> topMenus;

  const SalesReport({
    required this.totalSales,
    required this.trxCount,
    required this.voidCount,
    required this.itemsSold,
    required this.daily,
    required this.topMenus,
  });

  /// Rata-rata nilai per transaksi.
  int get average => trxCount == 0 ? 0 : (totalSales / trxCount).round();

  /// True jika tidak ada transaksi sama sekali pada periode ini.
  bool get isEmpty => trxCount == 0 && voidCount == 0;
}

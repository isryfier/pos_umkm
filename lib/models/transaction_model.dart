import 'menu_model.dart';

/// Satu baris di keranjang belanja (hanya di memori, belum disimpan ke database).
class CartItem {
  /// Data menu terbaru. Bisa diperbarui saat stok di database berubah.
  MenuModel menu;

  /// Jumlah porsi yang dibeli.
  int qty;

  CartItem({required this.menu, this.qty = 1});

  /// Subtotal = harga x jumlah.
  int get subtotal => menu.price * qty;
}

/// Satu item di dalam transaksi yang sudah tersimpan.
/// Nama dan harga disalin saat transaksi, supaya struk lama tidak berubah
/// walaupun menu diedit atau dihapus kemudian.
class TransactionItemModel {
  final int? id;
  final int? transactionId;
  final int menuId;
  final String menuName;
  final int price;
  final int qty;

  const TransactionItemModel({
    this.id,
    this.transactionId,
    required this.menuId,
    required this.menuName,
    required this.price,
    required this.qty,
  });

  int get subtotal => price * qty;

  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    return TransactionItemModel(
      id: map['id'] as int?,
      transactionId: map['transactionId'] as int?,
      menuId: map['menuId'] as int,
      menuName: map['menuName'] as String,
      price: map['price'] as int,
      qty: map['qty'] as int,
    );
  }

  /// [transactionId] diisi saat menyimpan, setelah ID transaksi dibuat.
  Map<String, dynamic> toMap({int? transactionId}) {
    return {
      if (id != null) 'id': id,
      'transactionId': transactionId ?? this.transactionId,
      'menuId': menuId,
      'menuName': menuName,
      'price': price,
      'qty': qty,
    };
  }
}

/// Satu transaksi penjualan (struk).
class TransactionModel {
  final int? id;

  /// Nomor struk, contoh: INV-20261026-001.
  final String invoiceNo;

  final DateTime createdAt;

  /// Nama kasir yang melayani.
  final String cashierName;

  /// Total belanja.
  final int total;

  /// Uang yang diterima dari pembeli.
  final int paidAmount;

  /// Kembalian.
  final int changeAmount;

  final List<TransactionItemModel> items;

  const TransactionModel({
    this.id,
    required this.invoiceNo,
    required this.createdAt,
    required this.cashierName,
    required this.total,
    required this.paidAmount,
    required this.changeAmount,
    this.items = const [],
  });

  factory TransactionModel.fromMap(
    Map<String, dynamic> map, {
    List<TransactionItemModel> items = const [],
  }) {
    return TransactionModel(
      id: map['id'] as int?,
      invoiceNo: map['invoiceNo'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      cashierName: map['cashierName'] as String,
      total: map['total'] as int,
      paidAmount: map['paidAmount'] as int,
      changeAmount: map['changeAmount'] as int,
      items: items,
    );
  }

  /// Item tidak ikut di sini, karena disimpan di tabel terpisah.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoiceNo': invoiceNo,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'cashierName': cashierName,
      'total': total,
      'paidAmount': paidAmount,
      'changeAmount': changeAmount,
    };
  }
}

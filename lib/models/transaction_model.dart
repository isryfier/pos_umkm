import 'menu_model.dart';

/// Satu baris di keranjang belanja (hanya di memori, belum disimpan ke database).
class CartItem {
  /// Data menu terbaru. Bisa diperbarui saat stok di database berubah.
  MenuModel menu;

  /// Jumlah porsi yang dibeli.
  int qty;

  /// Catatan pesanan untuk baris ini, misalnya "tanpa gula". Kosong jika tidak ada.
  String note;

  CartItem({required this.menu, this.qty = 1, this.note = ''});

  /// Kunci unik baris keranjang: menu yang sama dengan catatan berbeda
  /// menjadi baris terpisah (mis. 1 kopi biasa + 1 kopi tanpa gula).
  String get key => '${menu.id}|$note';

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

  /// Catatan pesanan (null jika tidak ada).
  final String? note;

  const TransactionItemModel({
    this.id,
    this.transactionId,
    required this.menuId,
    required this.menuName,
    required this.price,
    required this.qty,
    this.note,
  });

  int get subtotal => price * qty;

  /// True jika item ini punya catatan.
  bool get hasNote => note != null && note!.trim().isNotEmpty;

  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    return TransactionItemModel(
      id: map['id'] as int?,
      transactionId: map['transactionId'] as int?,
      menuId: map['menuId'] as int,
      menuName: map['menuName'] as String,
      price: map['price'] as int,
      qty: map['qty'] as int,
      note: map['note'] as String?,
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
      'note': note,
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

  /// Status transaksi: 'SUCCESS' (berhasil) atau 'VOID' (dibatalkan).
  final String status;

  final List<TransactionItemModel> items;

  /// True jika transaksi sudah dibatalkan.
  bool get isVoid => status == 'VOID';

  const TransactionModel({
    this.id,
    required this.invoiceNo,
    required this.createdAt,
    required this.cashierName,
    required this.total,
    required this.paidAmount,
    required this.changeAmount,
    this.status = 'SUCCESS',
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
      status: (map['status'] as String?) ?? 'SUCCESS',
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
      'status': status,
    };
  }
}

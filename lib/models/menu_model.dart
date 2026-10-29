/// Model data menu (produk) yang dijual.
class MenuModel {
  /// ID dibuat otomatis oleh SQLite. Bernilai null untuk menu yang belum disimpan.
  final int? id;

  /// Nama menu, misalnya "Thai Tea".
  final String name;

  /// Harga dalam rupiah (bilangan bulat, tanpa desimal).
  final int price;

  /// Nama kategori, misalnya "Tea Series". Kategori dikelola Owner.
  final String category;

  /// Jumlah stok yang tersedia (hanya dipakai jika [trackStock] = true).
  final int stock;

  /// true = stok dihitung dan berkurang tiap terjual.
  /// false = stok tak terbatas (selalu bisa dijual).
  final bool trackStock;

  /// Penanda menu bisa dijual atau tidak (misalnya sedang ditutup).
  final bool isAvailable;

  const MenuModel({
    this.id,
    required this.name,
    required this.price,
    required this.category,
    this.stock = 0,
    this.trackStock = true,
    this.isAvailable = true,
  });

  /// True jika menu tidak bisa dijual sama sekali saat ini.
  bool get isSoldOut => !isAvailable || (trackStock && stock <= 0);

  /// True jika menu masih cukup untuk dijual sebanyak [qty] porsi.
  bool hasStockFor(int qty) => isAvailable && (!trackStock || qty <= stock);

  /// Membuat salinan menu dengan sebagian data diubah.
  MenuModel copyWith({
    int? id,
    String? name,
    int? price,
    String? category,
    int? stock,
    bool? trackStock,
    bool? isAvailable,
  }) {
    return MenuModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      trackStock: trackStock ?? this.trackStock,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  /// Membaca satu baris dari database SQLite menjadi MenuModel.
  factory MenuModel.fromMap(Map<String, dynamic> map) {
    return MenuModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: map['price'] as int,
      category: map['category'] as String,
      stock: map['stock'] as int,
      trackStock: ((map['trackStock'] as int?) ?? 1) == 1,
      isAvailable: (map['isAvailable'] as int) == 1,
    );
  }

  /// Mengubah MenuModel menjadi Map untuk disimpan ke database.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price': price,
      'category': category,
      'stock': stock,
      'trackStock': trackStock ? 1 : 0,
      'isAvailable': isAvailable ? 1 : 0,
    };
  }
}

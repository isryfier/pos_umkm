/// Kategori menu: makanan atau minuman.
enum MenuCategory { makanan, minuman }

/// Model data menu (produk) yang dijual.
class MenuModel {
  /// ID dibuat otomatis oleh SQLite. Bernilai null untuk menu yang belum disimpan.
  final int? id;

  /// Nama menu, misalnya "Nasi Goreng".
  final String name;

  /// Harga dalam rupiah (bilangan bulat, tanpa desimal).
  final int price;

  /// Kategori: makanan atau minuman.
  final MenuCategory category;

  /// Jumlah stok yang tersedia.
  final int stock;

  /// Penanda menu bisa dijual atau tidak (misalnya sedang kosong/ditutup).
  final bool isAvailable;

  const MenuModel({
    this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.stock,
    this.isAvailable = true,
  });

  /// Label kategori dalam Bahasa Indonesia untuk ditampilkan di layar.
  String get categoryLabel =>
      category == MenuCategory.makanan ? 'Makanan' : 'Minuman';

  /// Membuat salinan menu dengan sebagian data diubah.
  /// Berguna saat edit harga/stok tanpa mengubah field lainnya.
  MenuModel copyWith({
    int? id,
    String? name,
    int? price,
    MenuCategory? category,
    int? stock,
    bool? isAvailable,
  }) {
    return MenuModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  /// Membaca satu baris dari database SQLite menjadi MenuModel.
  /// SQLite tidak punya tipe boolean, jadi isAvailable disimpan sebagai 0/1.
  factory MenuModel.fromMap(Map<String, dynamic> map) {
    return MenuModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: map['price'] as int,
      category: map['category'] == 'minuman'
          ? MenuCategory.minuman
          : MenuCategory.makanan,
      stock: map['stock'] as int,
      isAvailable: (map['isAvailable'] as int) == 1,
    );
  }

  /// Mengubah MenuModel menjadi Map untuk disimpan ke database.
  /// ID tidak dimasukkan kalau masih null supaya SQLite membuatnya sendiri.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price': price,
      'category': category.name, // 'makanan' atau 'minuman'
      'stock': stock,
      'isAvailable': isAvailable ? 1 : 0,
    };
  }
}

/// Peran pengguna dalam aplikasi.
/// - owner : pemilik usaha, akses penuh.
/// - staff : kasir/karyawan, akses terbatas.
enum UserRole { owner, staff }

/// Model data pengguna untuk sistem login multi-user.
class UserModel {
  /// ID unik pengguna.
  final String id;

  /// Username untuk login (huruf kecil, tanpa spasi).
  final String username;

  /// Nama lengkap yang ditampilkan di aplikasi.
  final String name;

  /// Peran pengguna (owner atau staff).
  final UserRole role;

  /// PIN untuk otorisasi khusus (misalnya void transaksi, diskon, tutup kasir).
  /// Catatan: pada sesi berikutnya PIN sebaiknya disimpan dalam bentuk hash.
  final String pin;

  const UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.pin,
  });

  /// Helper agar pengecekan peran lebih mudah dibaca.
  bool get isOwner => role == UserRole.owner;
  bool get isStaff => role == UserRole.staff;

  /// Label peran dalam Bahasa Indonesia untuk ditampilkan di UI.
  String get roleLabel => isOwner ? 'Owner' : 'Kasir';

  /// Membuat UserModel dari Map (siap dipakai untuk database/JSON nanti).
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      username: map['username'] as String,
      name: map['name'] as String,
      role: map['role'] == 'owner' ? UserRole.owner : UserRole.staff,
      pin: map['pin'] as String,
    );
  }

  /// Mengubah UserModel menjadi Map (untuk disimpan ke database/JSON).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role.name, // 'owner' atau 'staff'
      'pin': pin,
    };
  }
}

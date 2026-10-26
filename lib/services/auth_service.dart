import '../models/user_model.dart';

/// Layanan autentikasi sederhana (sementara memakai data dummy di memori).
///
/// Pada sesi berikutnya, kelas ini bisa diganti dengan database lokal
/// (SQLite/Drift/Hive) tanpa mengubah kode di LoginScreen.
class AuthService {
  /// Daftar akun contoh. Password disimpan polos HANYA untuk demo Sesi 1.
  static const List<Map<String, String>> _accounts = [
    {
      'id': 'u1',
      'username': 'owner',
      'name': 'Pak Budi (Owner)',
      'role': 'owner',
      'pin': '123456',
      'password': 'owner123',
    },
    {
      'id': 'u2',
      'username': 'kasir',
      'name': 'Siti (Kasir)',
      'role': 'staff',
      'pin': '1111',
      'password': 'kasir123',
    },
  ];

  /// Mencoba login. Mengembalikan [UserModel] jika berhasil, atau null jika gagal.
  Future<UserModel?> login(String username, String password) async {
    // Simulasi jeda proses agar indikator loading terlihat.
    await Future.delayed(const Duration(milliseconds: 600));

    for (final acc in _accounts) {
      if (acc['username'] == username.trim().toLowerCase() &&
          acc['password'] == password) {
        return UserModel.fromMap(acc);
      }
    }
    return null;
  }

  /// Memeriksa PIN milik Owner. Dipakai untuk otorisasi aksi sensitif,
  /// misalnya membatalkan (void) transaksi yang dilakukan oleh kasir.
  Future<bool> verifyOwnerPin(String pin) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _accounts.any(
      (acc) => acc['role'] == 'owner' && acc['pin'] == pin.trim(),
    );
  }
}

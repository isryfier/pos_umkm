import '../models/user_model.dart';
import '../utils/security.dart';
import 'database_service.dart';

/// Layanan akun: login, PIN owner, dan pengelolaan akun kasir.
///
/// Akun disimpan di database SQLite. Password dan PIN disimpan sebagai hash,
/// bukan teks asli. Fungsi yang bisa gagal mengembalikan pesan error
/// (String) atau null jika berhasil, supaya mudah ditampilkan di layar.
class AuthService {
  final _db = DatabaseService.instance;

  /// Mengubah satu baris database menjadi [UserModel].
  /// Field `pin` sengaja dikosongkan: PIN tidak pernah keluar dari database.
  UserModel _toModel(Map<String, Object?> r) {
    return UserModel(
      id: (r['id'] as int).toString(),
      username: r['username'] as String,
      name: r['name'] as String,
      role: r['role'] == 'owner' ? UserRole.owner : UserRole.staff,
      pin: '',
    );
  }

  /// Mencoba login. Mengembalikan [UserModel] jika berhasil, atau null jika gagal.
  Future<UserModel?> login(String username, String password) async {
    final row = await _db.findUser(username.trim().toLowerCase());
    if (row == null) return null;

    final salt = row['salt'] as String;
    final ok = Security.hash(salt, 'pw', password) == row['passwordHash'];
    return ok ? _toModel(row) : null;
  }

  /// Memeriksa PIN milik Owner. Dipakai untuk otorisasi aksi sensitif,
  /// misalnya membatalkan (void) transaksi.
  Future<bool> verifyOwnerPin(String pin) async {
    final owners = await _db.getUsersByRole('owner');
    for (final o in owners) {
      final hash = o['pinHash'] as String?;
      if (hash != null && Security.hash(o['salt'] as String, 'pin', pin.trim()) == hash) {
        return true;
      }
    }
    return false;
  }

  /// True jika akun owner masih memakai password bawaan (`owner123`)
  /// atau PIN bawaan (`123456`). Dipakai untuk menampilkan pengingat di dashboard.
  Future<bool> hasDefaultOwnerCredentials(String userId) async {
    final row = await _db.getUserById(int.parse(userId));
    if (row == null || row['role'] != 'owner') return false;

    final salt = row['salt'] as String;
    final defaultPassword =
        Security.hash(salt, 'pw', 'owner123') == row['passwordHash'];
    final defaultPin = Security.hash(salt, 'pin', '123456') == row['pinHash'];
    return defaultPassword || defaultPin;
  }

  /// Daftar semua akun kasir.
  Future<List<UserModel>> getCashiers() async {
    final rows = await _db.getUsersByRole('staff');
    return rows.map(_toModel).toList();
  }

  /// Menambah akun kasir. Mengembalikan pesan error, atau null jika berhasil.
  Future<String?> addCashier({
    required String name,
    required String username,
    required String password,
  }) async {
    final n = name.trim();
    final u = username.trim().toLowerCase();

    if (n.isEmpty) return 'Nama wajib diisi';
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(u)) {
      return 'Username 3-20 karakter: huruf kecil, angka, atau _';
    }
    if (password.length < 6) return 'Password minimal 6 karakter';
    if (await _db.findUser(u) != null) return 'Username sudah dipakai';

    final salt = Security.generateSalt();
    await _db.insertUser({
      'username': u,
      'name': n,
      'role': 'staff',
      'salt': salt,
      'passwordHash': Security.hash(salt, 'pw', password),
      'pinHash': null, // kasir tidak punya PIN: otorisasi hanya lewat PIN Owner
    });
    return null;
  }

  /// Owner mengatur ulang password seorang kasir.
  Future<String?> resetCashierPassword(String userId, String newPassword) async {
    if (newPassword.length < 6) return 'Password minimal 6 karakter';

    final row = await _db.getUserById(int.parse(userId));
    if (row == null || row['role'] != 'staff') return 'Akun kasir tidak ditemukan';

    await _db.updateUser(int.parse(userId), {
      'passwordHash': Security.hash(row['salt'] as String, 'pw', newPassword),
    });
    return null;
  }

  /// Menghapus akun kasir. Riwayat transaksinya tetap tersimpan.
  Future<String?> deleteCashier(String userId) async {
    final count = await _db.deleteStaff(int.parse(userId));
    return count == 0 ? 'Akun kasir tidak ditemukan' : null;
  }

  /// Mengganti password akun sendiri (harus menyebut password lama).
  Future<String?> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final row = await _db.getUserById(int.parse(userId));
    if (row == null) return 'Akun tidak ditemukan';

    final salt = row['salt'] as String;
    if (Security.hash(salt, 'pw', oldPassword) != row['passwordHash']) {
      return 'Password lama salah';
    }
    if (newPassword.length < 6) return 'Password baru minimal 6 karakter';

    await _db.updateUser(int.parse(userId), {
      'passwordHash': Security.hash(salt, 'pw', newPassword),
    });
    return null;
  }

  /// Mengganti PIN owner (harus menyebut PIN lama).
  Future<String?> changeOwnerPin({
    required String userId,
    required String oldPin,
    required String newPin,
  }) async {
    final row = await _db.getUserById(int.parse(userId));
    if (row == null || row['role'] != 'owner') return 'Akun owner tidak ditemukan';

    final salt = row['salt'] as String;
    if (Security.hash(salt, 'pin', oldPin) != row['pinHash']) {
      return 'PIN lama salah';
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(newPin)) {
      return 'PIN baru harus 4-6 angka';
    }

    await _db.updateUser(int.parse(userId), {
      'pinHash': Security.hash(salt, 'pin', newPin),
    });
    return null;
  }
}

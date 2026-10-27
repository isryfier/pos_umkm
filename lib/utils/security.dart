import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Alat sederhana untuk menyimpan password dan PIN dalam bentuk hash.
/// Yang tersimpan di database hanya hash, bukan password aslinya.
class Security {
  Security._();

  /// Membuat "garam" acak. Garam membuat dua pengguna dengan password sama
  /// tetap menghasilkan hash yang berbeda.
  static String generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Menghasilkan hash SHA-256 dari [secret].
  /// [purpose] ('pw' atau 'pin') memisahkan hash password dari hash PIN.
  static String hash(String salt, String purpose, String secret) {
    return sha256.convert(utf8.encode('$salt:$purpose:$secret')).toString();
  }
}

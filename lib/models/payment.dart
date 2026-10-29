/// Metode pembayaran. Disimpan sebagai teks di database.
class PaymentMethod {
  static const String cash = 'TUNAI';
  static const String qris = 'QRIS';
  static const String transfer = 'TRANSFER';

  /// Pilihan di layar bayar, sesuai urutan tampil.
  static const List<String> all = [cash, qris, transfer];

  /// Nama yang ditampilkan.
  static String label(String method) {
    switch (method) {
      case qris:
        return 'QRIS';
      case transfer:
        return 'Transfer';
      default:
        return 'Tunai';
    }
  }
}

/// Pilihan aplikasi/bank di bawah QRIS.
const List<String> qrisChannels = [
  'M-Banking / Bank',
  'GoPay',
  'ShopeePay',
  'OVO',
  'DANA',
  'Lainnya',
];

/// Label lengkap, contoh: "Tunai", "QRIS - GoPay".
String paymentLabel(String method, String? channel) {
  final base = PaymentMethod.label(method);
  if (channel == null || channel.trim().isEmpty) return base;
  return '$base - $channel';
}

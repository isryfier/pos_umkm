/// Mengubah angka menjadi format rupiah, contoh: 15000 -> "Rp 15.000".
String formatRupiah(int value) {
  final negative = value < 0;
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${negative ? '-' : ''}Rp $buf';
}

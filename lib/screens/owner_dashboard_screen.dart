import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'account_management_screen.dart';
import 'login_screen.dart';
import 'menu_management_screen.dart';
import 'sales_report_screen.dart';
import 'transaction_history_screen.dart';

/// Dashboard untuk Owner (akses penuh).
/// Berisi pintu masuk ke semua fitur owner. Menampilkan pengingat kalau
/// password atau PIN owner masih bawaan (belum diganti).
class OwnerDashboardScreen extends StatefulWidget {
  final UserModel user;

  const OwnerDashboardScreen({super.key, required this.user});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _auth = AuthService();

  /// True jika password/PIN owner masih bawaan.
  bool _hasDefaultCredentials = false;

  UserModel get user => widget.user;

  @override
  void initState() {
    super.initState();
    _checkCredentials();
  }

  Future<void> _checkCredentials() async {
    final isDefault = await _auth.hasDefaultOwnerCredentials(user.id);
    if (!mounted) return;
    setState(() => _hasDefaultCredentials = isDefault);
  }

  /// Membuka layar Kelola Akun. Saat kembali, pengingat dicek ulang
  /// supaya hilang otomatis setelah password/PIN diganti.
  void _openAccounts() {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => AccountManagementScreen(user: user)))
        .then((_) => _checkCredentials());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Owner'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pengingat keamanan: hilang setelah password & PIN diganti
              if (_hasDefaultCredentials) ...[
                Card(
                  color: Colors.orange.shade50,
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    title: const Text('Password/PIN masih bawaan'),
                    subtitle: const Text(
                        'Segera ganti di Kelola Akun supaya akun Anda aman.'),
                    trailing: TextButton(
                      onPressed: _openAccounts,
                      child: const Text('Ganti'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const Icon(Icons.verified_user, size: 72, color: Colors.deepOrange),
              const SizedBox(height: 16),
              const Text(
                'Selamat Datang Owner - Akses Penuh',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(user.name, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 32),

              // Kelola Menu & Stok
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const MenuManagementScreen()),
                  );
                },
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Kelola Menu & Stok'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Riwayat transaksi
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => TransactionHistoryScreen(user: user)),
                  );
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Riwayat Transaksi'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Laporan penjualan
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SalesReportScreen()),
                  );
                },
                icon: const Icon(Icons.bar_chart),
                label: const Text('Laporan Penjualan'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Kelola akun kasir, password, dan PIN
              OutlinedButton.icon(
                onPressed: _openAccounts,
                icon: const Icon(Icons.manage_accounts),
                label: const Text('Kelola Akun'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kembali ke halaman login dan hapus seluruh riwayat navigasi.
  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

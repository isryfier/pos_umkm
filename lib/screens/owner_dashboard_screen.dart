import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'login_screen.dart';
import 'pos_screen.dart';
import 'transaction_history_screen.dart';

/// Dashboard untuk Kasir/Staff (akses terbatas).
/// Sesi 2B: ditambah tombol menuju layar kasir (POS).
class CashierDashboardScreen extends StatelessWidget {
  final UserModel user;

  const CashierDashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Kasir'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.point_of_sale, size: 72, color: Colors.deepOrange),
              const SizedBox(height: 16),
              const Text(
                'Selamat Datang Kasir - Akses Terbatas',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(user.name, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 32),

              // Tombol menuju layar kasir (baru di Sesi 2B)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PosScreen(user: user)),
                  );
                },
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Mulai Transaksi'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Tombol menuju riwayat transaksi (baru di Sesi 3A)
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

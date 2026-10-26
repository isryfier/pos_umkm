import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'login_screen.dart';

/// Dashboard untuk Kasir/Staff (akses terbatas).
/// Sementara hanya menampilkan teks sambutan; fitur kasir menyusul di sesi berikutnya.
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

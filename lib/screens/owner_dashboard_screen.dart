import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'login_screen.dart';

/// Dashboard untuk Owner (akses penuh).
/// Sementara hanya menampilkan teks sambutan; fitur lengkap menyusul di sesi berikutnya.
class OwnerDashboardScreen extends StatelessWidget {
  final UserModel user;

  const OwnerDashboardScreen({super.key, required this.user});

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_user, size: 72, color: Colors.deepOrange),
              const SizedBox(height: 16),
              const Text(
                'Selamat Datang Owner - Akses Penuh',
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

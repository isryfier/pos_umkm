import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'cashier_dashboard_screen.dart';
import 'owner_dashboard_screen.dart';

/// Halaman login: pengguna memasukkan username & password,
/// lalu diarahkan ke dashboard sesuai perannya (owner / staff).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true; // sembunyikan/tampilkan password
  bool _isLoading = false; // status proses login

  @override
  void dispose() {
    // Bebaskan controller agar tidak terjadi kebocoran memori.
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Proses login: validasi form -> cek akun -> arahkan sesuai role.
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus(); // tutup keyboard
    setState(() => _isLoading = true);

    final UserModel? user = await _authService.login(
      _usernameController.text,
      _passwordController.text,
    );

    // Pastikan widget masih aktif setelah proses async selesai.
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username atau password salah'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Logika Role-Based Access Control sederhana:
    // owner -> Dashboard Owner, staff -> Dashboard Kasir.
    final Widget destination = user.isOwner
        ? OwnerDashboardScreen(user: user)
        : CashierDashboardScreen(user: user);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          // SingleChildScrollView mencegah overflow saat keyboard muncul.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                 key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo & judul aplikasi
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: colors.primaryContainer,
                      child: Icon(Icons.restaurant_menu,
                          size: 44, color: colors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'POS Kuliner',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Masuk untuk mulai berjualan',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),

                    // Input username
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Username wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Input password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Password wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // Tombol masuk
                    FilledButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('MASUK',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 24),

                    // Petunjuk akun demo (hapus pada versi produksi)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Akun demo:\n'
                        'Owner  -> owner / owner123\n'
                        'Kasir  -> kasir / kasir123',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

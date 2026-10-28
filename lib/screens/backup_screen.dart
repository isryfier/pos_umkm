import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/auth_service.dart';
import '../services/backup_service.dart';
import 'login_screen.dart';

/// Layar Backup & Pulihkan Data (khusus Owner).
/// - Backup: membuat satu file berisi semua data, lalu dibagikan
///   (Google Drive, WhatsApp, dll).
/// - Pulihkan: mengganti semua data dengan isi file backup. Meminta PIN Owner.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = BackupService();
  bool _busy = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Membuat file backup lalu membuka menu bagikan bawaan Android.
  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final file = await _service.createBackup();
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Backup POS Kuliner');
    } catch (_) {
      if (mounted) _toast('Gagal membuat backup');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Alur pemulihan: peringatan -> PIN Owner -> pilih file -> ganti data.
  Future<void> _restore() async {
    final agree = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 40),
        title: const Text('Pulihkan data?'),
        content: const Text(
          'Semua data saat ini (menu, transaksi, dan akun) akan DIGANTI '
          'dengan isi file backup. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    if (agree != true || !mounted) return;

    final authorized = await showDialog<bool>(
      context: context,
      builder: (_) => const _PinDialog(),
    );
    if (authorized != true || !mounted) return;

    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final String? path = picked?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.restore(path);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
          title: const Text('Pemulihan berhasil'),
          content: const Text(
            'Silakan login ulang. Gunakan akun yang ada di backup tersebut.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on BackupException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Pemulihan gagal');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Pulihkan')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Buat Backup',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'Membuat satu file berisi semua menu, transaksi, dan akun. '
                        'Simpan file itu ke Google Drive atau kirim ke WhatsApp '
                        'Anda sendiri.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _createBackup,
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Buat & Bagikan Backup'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pulihkan dari Backup',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'Dipakai saat ganti HP atau data hilang. Semua data '
                        'sekarang akan diganti dengan isi file backup. '
                        'Membutuhkan PIN Owner.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _restore,
                        icon: const Icon(Icons.settings_backup_restore),
                        label: const Text('Pilih File & Pulihkan'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tips: buat backup rutin, misalnya setiap selesai tutup toko. '
                'Jangan bagikan file backup ke orang lain karena berisi seluruh data usaha.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dialog PIN Owner. Mengembalikan true jika PIN benar, null jika dibatalkan.
class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  final _auth = AuthService();

  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.isEmpty) {
      setState(() => _error = 'PIN wajib diisi');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });

    final ok = await _auth.verifyOwnerPin(_controller.text);
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _checking = false;
        _error = 'PIN salah';
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PIN Owner'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'PIN',
          errorText: _error,
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: const Text('Konfirmasi'),
        ),
      ],
    );
  }
}

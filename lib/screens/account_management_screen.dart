import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Layar Kelola Akun (khusus Owner).
/// - Ubah password dan PIN milik owner sendiri.
/// - Tambah, reset password, dan hapus akun kasir.
class AccountManagementScreen extends StatefulWidget {
  /// Owner yang sedang login.
  final UserModel user;

  const AccountManagementScreen({super.key, required this.user});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final _auth = AuthService();

  List<UserModel> _cashiers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _auth.getCashiers();
    if (!mounted) return;
    setState(() {
      _cashiers = data;
      _loading = false;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Membuka dialog isian. Mengembalikan true jika berhasil disimpan.
  Future<bool> _showForm({
    required String title,
    required String submitLabel,
    required List<_FieldSpec> fields,
    required Future<String?> Function(List<String> values) onSubmit,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _FormDialog(
        title: title,
        submitLabel: submitLabel,
        fields: fields,
        onSubmit: onSubmit,
      ),
    );
    return ok == true;
  }

  Future<void> _addCashier() async {
    final ok = await _showForm(
      title: 'Tambah Kasir',
      submitLabel: 'Simpan',
      fields: const [
        _FieldSpec('Nama kasir', capitalize: true),
        _FieldSpec('Username (huruf kecil/angka)'),
        _FieldSpec('Password (min. 6 karakter)', obscure: true),
      ],
      onSubmit: (v) =>
          _auth.addCashier(name: v[0], username: v[1], password: v[2]),
    );
    if (ok) {
      _toast('Kasir ditambahkan');
      _load();
    }
  }

  Future<void> _resetPassword(UserModel cashier) async {
    final ok = await _showForm(
      title: 'Reset Password\n${cashier.name}',
      submitLabel: 'Simpan',
      fields: const [_FieldSpec('Password baru (min. 6 karakter)', obscure: true)],
      onSubmit: (v) => _auth.resetCashierPassword(cashier.id, v[0]),
    );
    if (ok) _toast('Password ${cashier.name} diperbarui');
  }

  Future<void> _deleteCashier(UserModel cashier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus kasir?'),
        content: Text(
            '"${cashier.name}" tidak bisa login lagi. Riwayat transaksinya tetap tersimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final err = await _auth.deleteCashier(cashier.id);
    if (!mounted) return;
    _toast(err ?? 'Kasir dihapus');
    _load();
  }

  Future<void> _changeMyPassword() async {
    final ok = await _showForm(
      title: 'Ubah Password Saya',
      submitLabel: 'Simpan',
      fields: const [
        _FieldSpec('Password lama', obscure: true),
        _FieldSpec('Password baru (min. 6 karakter)', obscure: true),
      ],
      onSubmit: (v) => _auth.changePassword(
        userId: widget.user.id,
        oldPassword: v[0],
        newPassword: v[1],
      ),
    );
    if (ok) _toast('Password diperbarui');
  }

  Future<void> _changeMyPin() async {
    final ok = await _showForm(
      title: 'Ubah PIN Owner',
      submitLabel: 'Simpan',
      fields: const [
        _FieldSpec('PIN lama', obscure: true, numeric: true, maxLength: 6),
        _FieldSpec('PIN baru (4-6 angka)',
            obscure: true, numeric: true, maxLength: 6),
      ],
      onSubmit: (v) => _auth.changeOwnerPin(
        userId: widget.user.id,
        oldPin: v[0],
        newPin: v[1],
      ),
    );
    if (ok) _toast('PIN diperbarui');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Akun')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCashier,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Tambah Kasir'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          // Akun owner sendiri
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Akun saya',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.user.name}  •  @${widget.user.username}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _changeMyPassword,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Ubah Password'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _changeMyPin,
                        icon: const Icon(Icons.pin_outlined),
                        label: const Text('Ubah PIN'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PIN Owner dipakai untuk menyetujui pembatalan (void) transaksi.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Akun kasir',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_cashiers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'Belum ada kasir.\nTekan "Tambah Kasir" untuk membuat akun.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (final c in _cashiers)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(c.name),
                  subtitle: Text('@${c.username}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'reset') _resetPassword(c);
                      if (v == 'delete') _deleteCashier(c);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'reset', child: Text('Reset password')),
                      PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Deskripsi satu kolom isian di dialog.
class _FieldSpec {
  final String label;
  final bool obscure;
  final bool numeric;
  final bool capitalize;
  final int? maxLength;

  const _FieldSpec(
    this.label, {
    this.obscure = false,
    this.numeric = false,
    this.capitalize = false,
    this.maxLength,
  });
}

/// Dialog isian serbaguna. [onSubmit] mengembalikan pesan error (ditampilkan
/// di dalam dialog) atau null jika berhasil, lalu dialog tertutup.
class _FormDialog extends StatefulWidget {
  final String title;
  final String submitLabel;
  final List<_FieldSpec> fields;
  final Future<String?> Function(List<String> values) onSubmit;

  const _FormDialog({
    required this.title,
    required this.submitLabel,
    required this.fields,
    required this.onSubmit,
  });

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late final List<TextEditingController> _controllers;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controllers = [for (final _ in widget.fields) TextEditingController()];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final err = await widget.onSubmit([for (final c in _controllers) c.text]);
    if (!mounted) return;

    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < widget.fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _controllers[i],
                  autofocus: i == 0,
                  obscureText: widget.fields[i].obscure,
                  autocorrect: false,
                  maxLength: widget.fields[i].maxLength,
                  keyboardType: widget.fields[i].numeric
                      ? TextInputType.number
                      : TextInputType.text,
                  textCapitalization: widget.fields[i].capitalize
                      ? TextCapitalization.words
                      : TextCapitalization.none,
                  inputFormatters: widget.fields[i].numeric
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : null,
                  decoration: InputDecoration(
                    labelText: widget.fields[i].label,
                    counterText: '',
                  ),
                ),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

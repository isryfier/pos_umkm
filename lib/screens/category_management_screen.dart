import 'package:flutter/material.dart';

import '../services/database_service.dart';

/// Halaman Kelola Kategori (khusus Owner): tambah, ganti nama, hapus.
/// Contoh kategori: "Tea Series", "Food Series", "Coffee".
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _db = DatabaseService.instance;

  List<String> _names = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final names = await _db.getCategories();
    final counts = await _db.getCategoryCounts();
    if (!mounted) return;
    setState(() {
      _names = names;
      _counts = counts;
      _loading = false;
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// Dialog isi nama. Mengembalikan teks atau null jika dibatalkan.
  Future<String?> _askName({String? initial}) {
    final c = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? 'Kategori Baru' : 'Ganti Nama'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'mis. Tea Series'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final name = await _askName();
    if (name == null) return;
    try {
      await _db.addCategory(name);
    } on CategoryException catch (e) {
      _toast(e.message);
    }
    await _load();
  }

  Future<void> _rename(String old) async {
    final name = await _askName(initial: old);
    if (name == null || name.trim() == old) return;
    try {
      await _db.renameCategory(old, name);
    } on CategoryException catch (e) {
      _toast(e.message);
    }
    await _load();
  }

  Future<void> _delete(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text('Kategori "$name" akan dihapus.'),
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
    if (ok != true) return;
    try {
      await _db.deleteCategory(name);
    } on CategoryException catch (e) {
      _toast(e.message);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Kategori'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: _names.length,
              itemBuilder: (_, i) {
                final n = _names[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(n,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${_counts[n] ?? 0} menu'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ganti nama',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _rename(n),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(n),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

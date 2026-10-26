import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/menu_model.dart';
import '../services/database_service.dart';

/// Halaman Kelola Menu & Stok (khusus Owner).
/// Fitur: lihat daftar menu (filter Makanan/Minuman), tambah, edit, ubah stok, hapus.
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final _db = DatabaseService.instance;

  List<MenuModel> _menus = [];
  MenuCategory? _filter; // null = tampilkan semua
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  /// Mengambil daftar menu dari database sesuai filter yang dipilih.
  Future<void> _loadMenus() async {
    setState(() => _loading = true);
    final data = await _db.getAllMenu(category: _filter);
    if (!mounted) return;
    setState(() {
      _menus = data;
      _loading = false;
    });
  }

  /// Membuka form tambah (existing == null) atau edit (existing != null).
  Future<void> _openForm([MenuModel? existing]) async {
    final result = await showModalBottomSheet<MenuModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MenuFormSheet(existing: existing),
    );
    if (result == null) return; // pengguna menutup form tanpa menyimpan

    if (existing == null) {
      await _db.insertMenu(result);
    } else {
      await _db.updateMenu(result);
    }
    await _loadMenus();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing == null ? 'Menu ditambahkan' : 'Menu diperbarui'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Mengubah stok cepat dengan tombol +/-.
  Future<void> _changeStock(MenuModel menu, int delta) async {
    final newStock = menu.stock + delta;
    if (newStock < 0) return; // stok tidak boleh negatif
    await _db.updateStock(menu.id!, newStock);
    await _loadMenus();
  }

  /// Minta konfirmasi sebelum menghapus menu.
  Future<void> _confirmDelete(MenuModel menu) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus menu?'),
        content: Text('"${menu.name}" akan dihapus permanen.'),
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
    await _db.deleteMenu(menu.id!);
    await _loadMenus();
  }

  /// Format angka menjadi rupiah, contoh: 15000 -> "Rp 15.000".
  String _rupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Menu & Stok')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Menu'),
      ),
      body: Column(
        children: [
          // Filter kategori
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                _filterChip('Semua', null),
                _filterChip('Makanan', MenuCategory.makanan),
                _filterChip('Minuman', MenuCategory.minuman),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _menus.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Belum ada menu.\nTekan "Tambah Menu" untuk mulai.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: _menus.length,
                        itemBuilder: (_, i) => _menuCard(_menus[i]),
                      ),
          ),
        ],
      ),
    );
  }

  /// Satu chip filter kategori.
  Widget _filterChip(String label, MenuCategory? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) {
        setState(() => _filter = value);
        _loadMenus();
      },
    );
  }

  /// Kartu untuk satu menu.
  Widget _menuCard(MenuModel menu) {
    final habis = menu.stock == 0 || !menu.isAvailable;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('${_rupiah(menu.price)}  •  ${menu.categoryLabel}'),
                      if (habis)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Tidak tersedia',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openForm(menu),
                ),
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(menu),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Stok'),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _changeStock(menu, -1),
                ),
                Text(
                  '${menu.stock}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _changeStock(menu, 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Form tambah/edit menu, ditampilkan sebagai bottom sheet.
/// Mengembalikan [MenuModel] lewat Navigator.pop saat tombol Simpan ditekan.
class _MenuFormSheet extends StatefulWidget {
  final MenuModel? existing;

  const _MenuFormSheet({this.existing});

  @override
  State<_MenuFormSheet> createState() => _MenuFormSheetState();
}

class _MenuFormSheetState extends State<_MenuFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _priceC;
  late final TextEditingController _stockC;
  late MenuCategory _category;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameC = TextEditingController(text: e?.name ?? '');
    _priceC = TextEditingController(text: e?.price.toString() ?? '');
    _stockC = TextEditingController(text: e?.stock.toString() ?? '0');
    _category = e?.category ?? MenuCategory.makanan;
    _isAvailable = e?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _priceC.dispose();
    _stockC.dispose();
    super.dispose();
  }

  /// Validasi lalu kirim data menu kembali ke halaman sebelumnya.
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      MenuModel(
        id: widget.existing?.id,
        name: _nameC.text.trim(),
        price: int.parse(_priceC.text),
        category: _category,
        stock: int.parse(_stockC.text),
        isAvailable: _isAvailable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      // viewInsets.bottom mengangkat form saat keyboard muncul
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Edit Menu' : 'Tambah Menu',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama menu'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama menu wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceC,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Harga (Rp)', prefixText: 'Rp '),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Harga harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockC,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Stok'),
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Stok wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              SegmentedButton<MenuCategory>(
                segments: const [
                  ButtonSegment(
                    value: MenuCategory.makanan,
                    label: Text('Makanan'),
                    icon: Icon(Icons.restaurant),
                  ),
                  ButtonSegment(
                    value: MenuCategory.minuman,
                    label: Text('Minuman'),
                    icon: Icon(Icons.local_cafe),
                  ),
                ],
                selected: {_category},
                onSelectionChanged: (s) => setState(() => _category = s.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tersedia untuk dijual'),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('SIMPAN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

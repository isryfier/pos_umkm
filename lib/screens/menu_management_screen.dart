import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/menu_model.dart';
import '../services/database_service.dart';
import 'category_management_screen.dart';

/// Halaman Kelola Menu & Stok (khusus Owner).
/// Fitur: lihat daftar menu (filter per kategori), tambah, edit, ubah stok, hapus.
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final _db = DatabaseService.instance;

  List<MenuModel> _menus = [];
  List<String> _categories = [];
  String? _filter; // null = tampilkan semua
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  /// Mengambil daftar menu dari database sesuai filter yang dipilih.
  Future<void> _loadMenus() async {
    setState(() => _loading = true);
    final cats = await _db.getCategories();
    if (_filter != null && !cats.contains(_filter)) _filter = null;
    final data = await _db.getAllMenu(category: _filter);
    if (!mounted) return;
    setState(() {
      _categories = cats;
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
      builder: (_) => _MenuFormSheet(
        existing: existing,
        categories: _categories,
        defaultCategory: _filter,
      ),
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
      appBar: AppBar(
        title: const Text('Kelola Menu & Stok'),
        actions: [
          IconButton(
            tooltip: 'Kelola kategori',
            icon: const Icon(Icons.category_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CategoryManagementScreen()),
              );
              _loadMenus();
            },
          ),
        ],
      ),
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('Semua', null),
                  for (final c in _categories) _filterChip(c, c),
                ],
              ),
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
  Widget _filterChip(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) {
          setState(() => _filter = value);
          _loadMenus();
        },
      ),
    );
  }

  /// Kartu untuk satu menu.
  Widget _menuCard(MenuModel menu) {
    final habis = menu.isSoldOut;

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
                      Text('${_rupiah(menu.price)}  •  ${menu.category}'),
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
            if (menu.trackStock)
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
              )
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('Stok'),
                    Spacer(),
                    Text('Tak terbatas ∞',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(width: 8),
                  ],
                ),
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
  final List<String> categories;

  /// Kategori yang sedang difilter, dipakai sebagai pilihan awal menu baru.
  final String? defaultCategory;

  const _MenuFormSheet({
    this.existing,
    required this.categories,
    this.defaultCategory,
  });

  @override
  State<_MenuFormSheet> createState() => _MenuFormSheetState();
}

class _MenuFormSheetState extends State<_MenuFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameC;
  late final TextEditingController _priceC;
  late final TextEditingController _stockC;
  late String? _category;
  late bool _trackStock;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameC = TextEditingController(text: e?.name ?? '');
    _priceC = TextEditingController(text: e?.price.toString() ?? '');
    _stockC = TextEditingController(text: e?.stock.toString() ?? '0');
    _category = e?.category ??
        widget.defaultCategory ??
        (widget.categories.isNotEmpty ? widget.categories.first : null);
    _trackStock = e?.trackStock ?? true;
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
        category: _category!,
        stock: _trackStock ? int.parse(_stockC.text) : (widget.existing?.stock ?? 0),
        trackStock: _trackStock,
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
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v),
                validator: (v) =>
                    v == null ? 'Pilih kategori (buat dulu di Kelola Kategori)' : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hitung stok'),
                subtitle: Text(_trackStock
                    ? 'Stok berkurang tiap terjual'
                    : 'Stok tak terbatas, selalu bisa dijual'),
                value: _trackStock,
                onChanged: (v) => setState(() => _trackStock = v),
              ),
              if (_trackStock)
                TextFormField(
                  controller: _stockC,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Stok'),
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Stok wajib diisi' : null,
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

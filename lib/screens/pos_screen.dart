import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/menu_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../utils/format.dart';

/// Layar kasir: pilih menu -> keranjang -> bayar tunai -> simpan transaksi.
class PosScreen extends StatefulWidget {
  /// Kasir yang sedang login (namanya dicatat di setiap transaksi).
  final UserModel user;

  const PosScreen({super.key, required this.user});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _db = DatabaseService.instance;

  List<MenuModel> _allMenus = [];
  MenuCategory? _filter; // null = tampilkan semua
  bool _loading = true;

  /// Keranjang: kunci = "idMenu|catatan" (lihat CartItem.key).
  /// Menu sama dengan catatan berbeda menjadi baris terpisah.
  final Map<String, CartItem> _cart = {};

  /// Total porsi satu menu di semua baris keranjang (untuk batas stok).
  int _menuQty(int menuId) => _cart.values
      .where((c) => c.menu.id == menuId)
      .fold(0, (sum, c) => sum + c.qty);

  int get _itemCount => _cart.values.fold(0, (sum, c) => sum + c.qty);
  int get _total => _cart.values.fold(0, (sum, c) => sum + c.subtotal);

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  /// Mengambil semua menu terbaru, lalu menyelaraskan isi keranjang
  /// (menu yang sudah dihapus dibuang, jumlah dibatasi sesuai stok).
  Future<void> _loadMenus() async {
    final data = await _db.getAllMenu();
    if (!mounted) return;
    setState(() {
      _allMenus = data;
      final byId = {for (final m in data) m.id!: m};
      _cart.removeWhere((_, c) => !byId.containsKey(c.menu.id));
      for (final c in _cart.values) {
        c.menu = byId[c.menu.id!]!;
      }
      // Batasi total porsi per menu sesuai stok (semua baris catatan dihitung).
      final used = <int, int>{};
      for (final c in _cart.values) {
        final left = c.menu.stock - (used[c.menu.id!] ?? 0);
        if (c.qty > left) c.qty = left < 0 ? 0 : left;
        used[c.menu.id!] = (used[c.menu.id!] ?? 0) + c.qty;
      }
      _cart.removeWhere((_, c) => c.qty <= 0);
      _loading = false;
    });
  }

  /// Menambah satu porsi ke keranjang (dibatasi oleh stok).
  void _addToCart(MenuModel menu) {
    // Ketuk di grid menambah ke baris tanpa catatan.
    final existing = _cart['${menu.id}|'];
    if (!menu.isAvailable || _menuQty(menu.id!) >= menu.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok ${menu.name} tidak cukup'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }
    setState(() {
      if (existing == null) {
        final c = CartItem(menu: menu);
        _cart[c.key] = c;
      } else {
        existing.qty++;
      }
    });
  }

  /// Mengubah jumlah item di keranjang. Jumlah 0 berarti item dihapus.
  void _changeQty(CartItem item, int delta) {
    setState(() {
      final n = item.qty + delta;
      if (n <= 0) {
        _cart.remove(item.key);
      } else if (delta < 0 ||
          _menuQty(item.menu.id!) + delta <= item.menu.stock) {
        item.qty = n;
      }
    });
  }

  /// Mengubah catatan satu baris. Karena kunci baris memuat catatan,
  /// baris dipindah ke kunci baru dan digabung jika sudah ada yang sama.
  void _setNote(CartItem item, String note) {
    final clean = note.trim();
    if (clean == item.note) return;
    setState(() {
      _cart.remove(item.key);
      item.note = clean;
      final other = _cart[item.key];
      if (other == null) {
        _cart[item.key] = item;
      } else {
        other.qty += item.qty;
      }
    });
  }

  /// Dialog isi catatan. Mengembalikan teks (boleh kosong) atau null jika batal.
  Future<String?> _askNote(CartItem item) {
    final controller = TextEditingController(text: item.note);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Catatan: ${item.menu.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'mis. tanpa gula, pedas, diskon 5rb',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final t in ['Tanpa gula', 'Less ice', 'Pedas', 'Tidak pedas'])
                  ActionChip(
                    label: Text(t),
                    onPressed: () => controller.text = t,
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  /// Menampilkan isi keranjang dalam bottom sheet.
  Future<void> _openCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final items = _cart.values.toList();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text(
                      'Keranjang',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() => _cart.clear());
                        Navigator.pop(sheetCtx);
                      },
                      child: const Text('Kosongkan'),
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final c = items[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.menu.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${formatRupiah(c.menu.price)} x ${c.qty} = ${formatRupiah(c.subtotal)}'),
                            InkWell(
                              onTap: () async {
                                final n = await _askNote(c);
                                if (n == null) return;
                                _setNote(c, n);
                                setSheet(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  c.note.isEmpty
                                      ? '+ Tambah catatan'
                                      : 'Catatan: ${c.note}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(ctx).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                _changeQty(c, -1);
                                setSheet(() {});
                                if (_cart.isEmpty) Navigator.pop(sheetCtx);
                              },
                            ),
                            Text('${c.qty}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                _changeQty(c, 1);
                                setSheet(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 16)),
                    const Spacer(),
                    Text(
                      formatRupiah(_total),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _checkout();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('BAYAR'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Proses pembayaran: minta uang diterima -> simpan transaksi -> tampilkan hasil.
  Future<void> _checkout() async {
    if (_cart.isEmpty) return;

    final total = _total;
    final paid = await showDialog<int>(
      context: context,
      builder: (_) => _PaymentDialog(total: total),
    );
    if (paid == null) return; // dibatalkan

    try {
      final invoiceNo = await _db.generateInvoiceNo();
      final change = paid - total;

      final trx = TransactionModel(
        invoiceNo: invoiceNo,
        createdAt: DateTime.now(),
        cashierName: widget.user.name,
        total: total,
        paidAmount: paid,
        changeAmount: change,
        items: _cart.values
            .map((c) => TransactionItemModel(
                  menuId: c.menu.id!,
                  menuName: c.menu.name,
                  price: c.menu.price,
                  qty: c.qty,
                  note: c.note.trim().isEmpty ? null : c.note.trim(),
                ))
            .toList(),
      );

      await _db.insertTransaction(trx);
      if (!mounted) return;

      setState(() => _cart.clear());
      await _loadMenus(); // stok di layar ikut berkurang
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: const Text('Transaksi Berhasil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(invoiceNo),
              const SizedBox(height: 12),
              Text('Total: ${formatRupiah(total)}'),
              Text('Dibayar: ${formatRupiah(paid)}'),
              const SizedBox(height: 4),
              Text(
                'Kembalian: ${formatRupiah(change)}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('SELESAI'),
            ),
          ],
        ),
      );
    } on StockException catch (e) {
      // Stok berubah sejak item dimasukkan (misalnya diubah Owner).
      await _loadMenus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan transaksi. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final menus = _filter == null
        ? _allMenus
        : _allMenus.where((m) => m.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kasir')),
      body: Column(
        children: [
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
                : menus.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Belum ada menu.\nMinta Owner menambahkannya di Kelola Menu.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: menus.length,
                        itemBuilder: (_, i) => _menuCard(menus[i]),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _cart.isEmpty ? null : _cartBar(),
    );
  }

  Widget _filterChip(String label, MenuCategory? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  /// Kartu satu menu di grid. Ketuk untuk menambah ke keranjang.
  Widget _menuCard(MenuModel menu) {
    final inCart = _menuQty(menu.id!);
    final soldOut = !menu.isAvailable || menu.stock <= 0;
    final colors = Theme.of(context).colorScheme;

    return Opacity(
      opacity: soldOut ? 0.45 : 1,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: soldOut ? null : () => _addToCart(menu),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      formatRupiah(menu.price),
                      style: TextStyle(
                          color: colors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      soldOut ? 'Habis' : 'Stok ${menu.stock}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (inCart > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    child: Text('$inCart', style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bilah ringkasan keranjang di bagian bawah layar.
  Widget _cartBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_itemCount item'),
                  Text(
                    formatRupiah(_total),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _openCart,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Keranjang'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog pembayaran tunai. Mengembalikan jumlah uang diterima (int),
/// atau null jika dibatalkan.
class _PaymentDialog extends StatefulWidget {
  final int total;

  const _PaymentDialog({required this.total});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _controller = TextEditingController();

  int get _paid => int.tryParse(_controller.text) ?? 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPaid(int value) {
    _controller.text = value.toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final enough = _paid >= widget.total;

    return AlertDialog(
      title: const Text('Pembayaran Tunai'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total: ${formatRupiah(widget.total)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Uang diterima',
                prefixText: 'Rp ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Uang pas'),
                  onPressed: () => _setPaid(widget.total),
                ),
                for (final v in [10000, 20000, 50000, 100000])
                  ActionChip(
                    label: Text(formatRupiah(v)),
                    onPressed: () => _setPaid(v),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _paid == 0
                  ? 'Masukkan uang diterima'
                  : enough
                      ? 'Kembalian: ${formatRupiah(_paid - widget.total)}'
                      : 'Kurang: ${formatRupiah(widget.total - _paid)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _paid == 0
                    ? null
                    : (enough ? Colors.green.shade700 : Colors.red),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: enough ? () => Navigator.pop(context, _paid) : null,
          child: const Text('Proses'),
        ),
      ],
    );
  }
}

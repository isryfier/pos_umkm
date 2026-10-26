import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transaction_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/format.dart';

/// Layar riwayat transaksi per hari.
/// Bisa dibuka oleh Owner maupun Kasir. Membatalkan (void) transaksi
/// selalu meminta PIN Owner.
class TransactionHistoryScreen extends StatefulWidget {
  /// Pengguna yang sedang login.
  final UserModel user;

  const TransactionHistoryScreen({super.key, required this.user});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final _db = DatabaseService.instance;

  DateTime _day = DateTime.now();
  List<TransactionModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Mengambil transaksi pada tanggal yang dipilih.
  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.getAllTransactions(day: _day);
    if (!mounted) return;
    setState(() {
      _list = data;
      _loading = false;
    });
  }

  /// Memilih tanggal lain lewat kalender.
  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    _day = picked;
    await _load();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _dateLabel(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
  String _timeLabel(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// Meminta PIN Owner, lalu membatalkan transaksi dan mengembalikan stok.
  Future<void> _voidTrx(TransactionModel trx) async {
    final authorized = await showDialog<bool>(
      context: context,
      builder: (_) => const _OwnerPinDialog(),
    );
    if (authorized != true) return;

    try {
      await _db.voidTransaction(trx.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi dibatalkan, stok dikembalikan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on VoidException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membatalkan transaksi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _load();
  }

  /// Menampilkan detail struk dalam bottom sheet.
  void _showDetail(TransactionModel trx) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      trx.invoiceNo,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (trx.isVoid) _voidBadge(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_dateLabel(trx.createdAt)} ${_timeLabel(trx.createdAt)}  •  ${trx.cashierName}',
              ),
              const Divider(height: 24),
              for (final item in trx.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${item.menuName}\n${item.qty} x ${formatRupiah(item.price)}'),
                      ),
                      Text(formatRupiah(item.subtotal)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              _row('Total', formatRupiah(trx.total), bold: true),
              _row('Dibayar', formatRupiah(trx.paidAmount)),
              _row('Kembalian', formatRupiah(trx.changeAmount)),
              const SizedBox(height: 16),
              if (!trx.isVoid)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _voidTrx(trx);
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Batalkan Transaksi (Void)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 16 : 14,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _voidBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'VOID',
        style: TextStyle(
            color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ringkasan hanya menghitung transaksi yang tidak di-void.
    final valid = _list.where((t) => !t.isVoid).toList();
    final sales = valid.fold<int>(0, (sum, t) => sum + t.total);
    final voidCount = _list.length - valid.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Pilih tanggal',
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDay,
          ),
        ],
      ),
      body: Column(
        children: [
          // Ringkasan hari yang dipilih
          Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isToday ? 'Hari ini' : _dateLabel(_day),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatRupiah(sales),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${valid.length} transaksi'
                    '${voidCount > 0 ? '  •  $voidCount dibatalkan' : ''}',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? const Center(child: Text('Belum ada transaksi'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _list.length,
                        itemBuilder: (_, i) => _trxCard(_list[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _trxCard(TransactionModel trx) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showDetail(trx),
        title: Row(
          children: [
            Flexible(
              child: Text(
                trx.invoiceNo,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: trx.isVoid ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (trx.isVoid) ...[
              const SizedBox(width: 8),
              _voidBadge(),
            ],
          ],
        ),
        subtitle: Text(
            '${_timeLabel(trx.createdAt)}  •  ${trx.cashierName}  •  ${trx.items.length} item'),
        trailing: Text(
          formatRupiah(trx.total),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: trx.isVoid ? Colors.grey : null,
            decoration: trx.isVoid ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

/// Dialog PIN Owner. Mengembalikan true jika PIN benar, null jika dibatalkan.
class _OwnerPinDialog extends StatefulWidget {
  const _OwnerPinDialog();

  @override
  State<_OwnerPinDialog> createState() => _OwnerPinDialogState();
}

class _OwnerPinDialogState extends State<_OwnerPinDialog> {
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Membatalkan transaksi membutuhkan PIN Owner.'),
          const SizedBox(height: 12),
          TextField(
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
        ],
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

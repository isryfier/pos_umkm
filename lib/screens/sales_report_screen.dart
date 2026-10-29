import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/payment.dart';
import '../models/report_model.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../utils/format.dart';

/// Pilihan rentang waktu laporan.
enum _Range { today, last7, last30, thisMonth, custom }

/// Layar Laporan Penjualan (khusus Owner).
/// Menampilkan omzet, jumlah transaksi, item terjual, penjualan per hari,
/// dan menu terlaris untuk rentang waktu yang dipilih.
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final _db = DatabaseService.instance;

  _Range _range = _Range.today;
  late DateTime _from;
  late DateTime _to;
  SalesReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _applyPreset(_Range.today);
  }

  /// Mengatur tanggal awal/akhir sesuai pilihan, lalu memuat laporan.
  void _applyPreset(_Range r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _range = r;
      switch (r) {
        case _Range.today:
          _from = today;
          _to = today;
          break;
        case _Range.last7:
          _from = DateTime(today.year, today.month, today.day - 6);
          _to = today;
          break;
        case _Range.last30:
          _from = DateTime(today.year, today.month, today.day - 29);
          _to = today;
          break;
        case _Range.thisMonth:
          _from = DateTime(today.year, today.month, 1);
          _to = today;
          break;
        case _Range.custom:
          break; // tanggal diatur lewat kalender
      }
    });
    _load();
  }

  /// Memilih rentang tanggal sendiri lewat kalender.
  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null) return;
    setState(() {
      _range = _Range.custom;
      _from = picked.start;
      _to = picked.end;
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _db.getSalesReport(from: _from, to: _to);
    if (!mounted) return;
    setState(() {
      _report = data;
      _loading = false;
    });
  }

  /// Membuat file CSV untuk rentang yang sedang dipilih, lalu membuka menu bagikan.
  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ExportService().createSalesCsv(from: _from, to: _to);
      if (path == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Tidak ada data untuk diekspor pada periode ini'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      await Share.shareXFiles(
        [XFile(path, mimeType: 'text/csv')],
        subject: 'Laporan penjualan $_rangeLabel',
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Gagal membuat file ekspor'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _dmy(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
  String _dm(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

  String get _rangeLabel => (_from.year == _to.year &&
          _from.month == _to.month &&
          _from.day == _to.day)
      ? _dmy(_from)
      : '${_dmy(_from)} - ${_dmy(_to)}';

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        actions: [
          IconButton(
            tooltip: 'Ekspor ke Excel (CSV)',
            icon: const Icon(Icons.ios_share),
            onPressed: _export,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _chip('Hari ini', _Range.today),
              _chip('7 hari', _Range.last7),
              _chip('30 hari', _Range.last30),
              _chip('Bulan ini', _Range.thisMonth),
              ChoiceChip(
                label: const Text('Pilih tanggal'),
                avatar: const Icon(Icons.calendar_month, size: 18),
                selected: _range == _Range.custom,
                onSelected: (_) => _pickCustom(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_rangeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_loading || report == null)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (report.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('Belum ada transaksi pada periode ini')),
            )
          else ...[
            _summary(report),
            const SizedBox(height: 20),
            _sectionTitle('Metode pembayaran'),
            _methodList(report),
            const SizedBox(height: 20),
            _sectionTitle('Penjualan per hari'),
            _dailyList(report),
            const SizedBox(height: 20),
            _sectionTitle('Menu terlaris'),
            _topMenuList(report),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, _Range r) {
    return ChoiceChip(
      label: Text(label),
      selected: _range == r,
      onSelected: (_) => _applyPreset(r),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Kartu omzet besar + empat kotak ringkasan.
  Widget _summary(SalesReport r) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Card(
          color: colors.primaryContainer,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total penjualan'),
                const SizedBox(height: 4),
                Text(
                  formatRupiah(r.totalSales),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _stat('Transaksi', '${r.trxCount}')),
            const SizedBox(width: 8),
            Expanded(child: _stat('Item terjual', '${r.itemsSold}')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _stat('Rata-rata/transaksi', formatRupiah(r.average))),
            const SizedBox(width: 8),
            Expanded(child: _stat('Dibatalkan', '${r.voidCount}')),
          ],
        ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  /// Total per metode bayar; QRIS dirinci per aplikasi/bank.
  Widget _methodList(SalesReport r) {
    final totals = <String, int>{};
    final counts = <String, int>{};
    for (final m in r.byMethod) {
      totals[m.method] = (totals[m.method] ?? 0) + m.total;
      counts[m.method] = (counts[m.method] ?? 0) + m.count;
    }
    final style = const TextStyle(fontWeight: FontWeight.w600);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            for (final method in PaymentMethod.all)
              if (totals.containsKey(method)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${PaymentMethod.label(method)}  (${counts[method]} transaksi)',
                          style: style,
                        ),
                      ),
                      Text(formatRupiah(totals[method]!), style: style),
                    ],
                  ),
                ),
                if (method == PaymentMethod.qris)
                  for (final m in r.byMethod.where(
                      (x) => x.method == PaymentMethod.qris && x.channel != null))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 0, 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${m.channel}  (${m.count})',
                                style: const TextStyle(fontSize: 13)),
                          ),
                          Text(formatRupiah(m.total),
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
              ],
          ],
        ),
      ),
    );
  }

  /// Satu baris per hari dengan batang proporsional terhadap hari tertinggi.
  /// Untuk rentang panjang (lebih dari 31 hari), hari tanpa penjualan disembunyikan.
  Widget _dailyList(SalesReport r) {
    var days = r.daily;
    if (days.length > 31) {
      days = days.where((d) => d.total > 0).toList();
    }
    final maxTotal = days.fold<int>(0, (m, d) => d.total > m ? d.total : m);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final d in days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(width: 44, child: Text(_dm(d.day))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(
                              height: 10,
                              color: Colors.black12,
                            ),
                            FractionallySizedBox(
                              widthFactor:
                                  maxTotal == 0 ? 0 : d.total / maxTotal,
                              child: Container(
                                height: 10,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 92,
                      child: Text(
                        formatRupiah(d.total),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Sepuluh menu terlaris berdasarkan jumlah porsi.
  Widget _topMenuList(SalesReport r) {
    final top = r.topMenus.take(10).toList();
    if (top.isEmpty) {
      return const Text('Belum ada item terjual');
    }
    final maxQty = top.first.qty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (int i = 0; i < top.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${i + 1}.',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            top[i].name,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('${top[i].qty} porsi'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maxQty == 0 ? 0 : top[i].qty / maxQty,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(formatRupiah(top[i].revenue),
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

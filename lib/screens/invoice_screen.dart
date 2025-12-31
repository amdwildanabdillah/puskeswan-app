import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Import Paket Tambahan
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:convert';
import 'dart:typed_data';

class InvoiceScreen extends StatefulWidget {
  final String role;
  const InvoiceScreen({super.key, required this.role});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _rawData = [];

  // Filter Waktu (Default Bulan Ini)
  String _filterWaktu = 'Bulan Ini';

  // Data yang sudah dikelompokkan
  Map<String, List<Map<String, dynamic>>> _groupedData = {};
  int _grandTotal = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userEmail = _supabase.auth.currentUser?.email;

      var query = _supabase.from('pelayanan').select();

      if (widget.role != 'Admin Gudang') {
        query = query.eq('dokter_email', userEmail!);
      }

      final data = await query.order('waktu', ascending: false);

      _rawData = List<Map<String, dynamic>>.from(data);

      _processData();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData() {
    List<Map<String, dynamic>> filteredList = _rawData;
    if (_filterWaktu == 'Bulan Ini') {
      final now = DateTime.now();
      filteredList = _rawData.where((item) {
        final date = DateTime.parse(item['waktu']);
        return date.year == now.year && date.month == now.month;
      }).toList();
    }

    Map<String, List<Map<String, dynamic>>> tempGroup = {};
    int total = 0;

    for (var item in filteredList) {
      String key;

      if (widget.role == 'Admin Gudang') {
        key = item['dokter_email'] ?? 'Tanpa Nama';
      } else {
        key = item['jenis_layanan'] ?? 'Layanan Umum';
      }

      if (!tempGroup.containsKey(key)) {
        tempGroup[key] = [];
      }
      tempGroup[key]!.add(item);
      total += (item['biaya'] as num).toInt();
    }

    setState(() {
      _groupedData = tempGroup;
      _grandTotal = total;
    });
  }

  String _formatRupiah(int nominal) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(nominal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        title: const Text("Laporan Keuangan"),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: Colors.purple[700],
                value: _filterWaktu,
                icon: const Icon(Icons.calendar_month, color: Colors.white),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                items: ['Bulan Ini', 'Semua Data'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() => _filterWaktu = newValue);
                    _processData();
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade900, Colors.purple.shade600],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  // Update: Pakai withValues biar gak warning deprecated
                  color: Colors.purple.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Total Pendapatan ($_filterWaktu)",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatRupiah(_grandTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.role == 'Admin Gudang'
                    ? "Kinerja Dokter"
                    : "Rekap Layanan",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedData.isEmpty
                ? const Center(child: Text("Belum ada data transaksi"))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _groupedData.keys.length,
                    itemBuilder: (context, index) {
                      String key = _groupedData.keys.elementAt(index);
                      List<Map<String, dynamic>> items = _groupedData[key]!;

                      int subTotal = items.fold(
                        0,
                        (sum, item) => sum + (item['biaya'] as num).toInt(),
                      );
                      int count = items.length;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple[100],
                            child: Icon(
                              widget.role == 'Admin Gudang'
                                  ? Icons.person
                                  : Icons.medical_services,
                              color: Colors.purple[800],
                            ),
                          ),
                          title: Text(
                            key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("$count Transaksi"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatRupiah(subTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => _DetailTransaksiPage(
                                  title: key,
                                  items: items,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CLASS DETAIL TRANSAKSI (FIX FINAL)
// ==========================================
class _DetailTransaksiPage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;

  const _DetailTransaksiPage({required this.title, required this.items});

  String _formatRupiah(int nominal) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(nominal);
  }

  String _formatTanggal(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (e) {
      return isoString;
    }
  }

  // --- 1. DOWNLOAD CSV (EXCEL) - FIXED ---
  Future<void> _exportCsv(BuildContext context) async {
    try {
      List<List<dynamic>> rows = [];
      // Header
      rows.add([
        "Tanggal",
        "Jenis Layanan",
        "Nama Peternak",
        "Detail Hewan",
        "Jumlah",
        "Biaya (Rp)",
      ]);

      // Isi Data
      for (var item in items) {
        rows.add([
          _formatTanggal(item['waktu']),
          item['jenis_layanan'] ?? '-',
          item['nama_peternak'] ?? '-',
          item['detail_hewan'] ?? '-',
          item['jumlah_hewan'] ?? 1,
          item['biaya'] ?? 0,
        ]);
      }

      // Total
      int total = items.fold(
        0,
        (sum, item) => sum + (item['biaya'] as num).toInt(),
      );
      rows.add(["", "", "", "", "TOTAL", total]);

      String csvData = const ListToCsvConverter().convert(rows);

      // FIX: Masukkan .csv langsung ke nama file
      String fileName =
          "Laporan_${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv";

      // FIX ERROR: Hapus 'ext' karena tidak dikenali, cukup 'name' dan 'mimeType'
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(utf8.encode(csvData)),
        mimeType: MimeType.csv,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil download CSV!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal export CSV: $e")));
      }
    }
  }

  // --- 2. PRINT PDF ---
  Future<void> _printPdf(BuildContext context) async {
    final doc = pw.Document();
    int total = items.fold(
      0,
      (sum, item) => sum + (item['biaya'] as num).toInt(),
    );
    final font = await PdfGoogleFonts.nunitoExtraLight();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Laporan Transaksi Puskeswan",
                style: pw.TextStyle(
                  font: font,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Kategori: $title",
                style: pw.TextStyle(font: font, fontSize: 18),
              ),
              pw.Text(
                "Tanggal Cetak: ${_formatTanggal(DateTime.now().toIso8601String())}",
                style: pw.TextStyle(
                  font: font,
                  fontSize: 12,
                  color: PdfColors.grey,
                ),
              ),
              pw.SizedBox(height: 20),

              // FIX DEPRECATED: TableHelper
              pw.TableHelper.fromTextArray(
                headers: ['Tanggal', 'Layanan', 'Peternak', 'Hewan', 'Biaya'],
                data: items.map((item) {
                  return [
                    _formatTanggal(item['waktu']),
                    item['jenis_layanan'] ?? '-',
                    item['nama_peternak'] ?? '-',
                    "${item['detail_hewan'] ?? '-'} (${item['jumlah_hewan']})",
                    _formatRupiah(item['biaya'] ?? 0),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.purple800,
                ),
                cellAlignments: {4: pw.Alignment.centerRight},
              ),

              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total: ${_formatRupiah(total)}",
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    int total = items.fold(
      0,
      (sum, item) => sum + (item['biaya'] as num).toInt(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _exportCsv(context),
            icon: const Icon(Icons.table_view),
            tooltip: "Download Excel (CSV)",
          ),
          IconButton(
            onPressed: () => _printPdf(context),
            icon: const Icon(Icons.print),
            tooltip: "Cetak PDF",
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.purple[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${items.length} Transaksi",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Total: ${_formatRupiah(total)}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.receipt, color: Colors.grey),
                    title: Text(item['jenis_layanan'] ?? '-'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Peternak: ${item['nama_peternak']}"),
                        Text(
                          _formatTanggal(item['waktu']),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      _formatRupiah(item['biaya'] ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

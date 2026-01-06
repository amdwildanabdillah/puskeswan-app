import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import '../services/database_helper.dart';

class InvoiceScreen extends StatefulWidget {
  final String role;
  const InvoiceScreen({super.key, required this.role});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _allTransaksi = [];
  List<Map<String, dynamic>> _filteredTransaksi = [];
  bool _isLoading = true;
  int _totalSangu = 0;

  DateTimeRange? _selectedDateRange;
  String _activeFilterLabel = "Semua";
  String? _selectedDokterEmail;
  List<String> _dokterList = ['Semua Dokter'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchDokterList();
    await _fetchHistory();
  }

  Future<void> _fetchDokterList() async {
    if (widget.role == 'Admin Gudang') {
      try {
        final data = await _supabase.from('pelayanan').select('dokter_email');
        final List<String> emails = ['Semua Dokter'];
        for (var item in data) {
          final email = item['dokter_email'] as String;
          if (!emails.contains(email)) emails.add(email);
        }
        if (mounted) setState(() => _dokterList = emails);
      } catch (e) {
        /* Silent */
      }
    }
  }

  // --- FETCH DATA ---
  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final userEmail = _supabase.auth.currentUser?.email;
      var queryBuilder = _supabase.from('pelayanan').select();

      if (_selectedDateRange != null) {
        queryBuilder = queryBuilder.gte(
          'waktu',
          _selectedDateRange!.start.toIso8601String(),
        );
        final endOfDay = _selectedDateRange!.end.add(
          const Duration(hours: 23, minutes: 59, seconds: 59),
        );
        queryBuilder = queryBuilder.lte('waktu', endOfDay.toIso8601String());
      }

      if (widget.role == 'Admin Gudang') {
        if (_selectedDokterEmail != null &&
            _selectedDokterEmail != 'Semua Dokter') {
          queryBuilder = queryBuilder.eq('dokter_email', _selectedDokterEmail!);
        }
      } else {
        queryBuilder = queryBuilder.eq('dokter_email', userEmail!);
      }

      final onlineData = await queryBuilder.order('waktu', ascending: false);

      List<Map<String, dynamic>> allOffline = [];
      if (!kIsWeb) {
        allOffline = await DatabaseHelper().getTransaksiPending();
      }

      List<Map<String, dynamic>> gabungan = [];

      for (var item in allOffline) {
        bool passDate = true;
        bool passDokter = true;

        if (_selectedDateRange != null) {
          DateTime itemDate = DateTime.parse(item['waktu']);
          passDate =
              itemDate.isAfter(
                _selectedDateRange!.start.subtract(const Duration(seconds: 1)),
              ) &&
              itemDate.isBefore(
                _selectedDateRange!.end.add(const Duration(days: 1)),
              );
        }

        if (widget.role == 'Admin Gudang') {
          if (_selectedDokterEmail != null &&
              _selectedDokterEmail != 'Semua Dokter') {
            passDokter = item['dokter_email'] == _selectedDokterEmail;
          }
        } else {
          passDokter = item['dokter_email'] == userEmail;
        }

        if (passDate && passDokter) {
          final newItem = Map<String, dynamic>.from(item);
          newItem['status'] = 'offline';
          gabungan.add(newItem);
        }
      }

      for (var item in onlineData) {
        final newItem = Map<String, dynamic>.from(item);
        newItem['status'] = 'online';
        gabungan.add(newItem);
      }

      if (mounted) {
        setState(() {
          _allTransaksi = gabungan;
          _filteredTransaksi = gabungan;
          _calculateTotal();
          _isLoading = false;
        });
        _runSearch(_searchController.text);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _runSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredTransaksi = _allTransaksi;
        _calculateTotal();
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredTransaksi = _allTransaksi.where((item) {
        final peternak = (item['nama_peternak'] ?? '').toString().toLowerCase();
        final dokter = (item['dokter_email'] ?? '').toString().toLowerCase();
        final diagnosa = (item['diagnosa'] ?? '').toString().toLowerCase();
        return peternak.contains(lowerQuery) ||
            dokter.contains(lowerQuery) ||
            diagnosa.contains(lowerQuery);
      }).toList();
      _calculateTotal();
    });
  }

  void _calculateTotal() {
    int total = 0;
    for (var item in _filteredTransaksi) {
      total += (item['biaya'] as num).toInt();
    }
    setState(() => _totalSangu = total);
  }

  Map<String, List<Map<String, dynamic>>> _groupData() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in _filteredTransaksi) {
      String key;
      if (widget.role == 'Admin Gudang') {
        String rawEmail = item['dokter_email']?.toString() ?? 'Tanpa Nama';
        key = "Dr. ${rawEmail.split('@')[0]}";
      } else {
        key = item['nama_peternak']?.toString() ?? 'Umum';
      }
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(item);
    }
    return grouped;
  }

  int _calculateSubTotal(List<Map<String, dynamic>> list) {
    int total = 0;
    for (var item in list) {
      total += (item['biaya'] as num).toInt();
    }
    return total;
  }

  void _setQuickFilter(String type) {
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end = now;

    if (type == 'Hari Ini') {
      start = DateTime(now.year, now.month, now.day);
    } else if (type == '7 Hari') {
      start = now.subtract(const Duration(days: 7));
    } else if (type == 'Bulan Ini') {
      start = DateTime(now.year, now.month, 1);
    } else {
      setState(() {
        _selectedDateRange = null;
        _activeFilterLabel = "Semua";
      });
      _fetchHistory();
      return;
    }

    setState(() {
      _selectedDateRange = DateTimeRange(start: start, end: end);
      _activeFilterLabel = type;
    });
    _fetchHistory();
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.purple,
            colorScheme: const ColorScheme.light(
              primary: Colors.purple,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _activeFilterLabel = "Custom";
      });
      _fetchHistory();
    }
  }

  // --- EDIT TRANSAKSI ---
  Future<void> _editTransaksiDialog(Map<String, dynamic> item) async {
    final biayaCtrl = TextEditingController(text: item['biaya'].toString());
    final diagnosaCtrl = TextEditingController(text: item['diagnosa'] ?? '');
    final layananCtrl = TextEditingController(
      text: item['jenis_layanan'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Edit Transaksi",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: biayaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Biaya (Rp)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: diagnosaCtrl,
              decoration: const InputDecoration(
                labelText: "Diagnosa",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: layananCtrl,
              decoration: const InputDecoration(
                labelText: "Layanan",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                int biayaBaru = int.parse(
                  biayaCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                );
                await _supabase
                    .from('pelayanan')
                    .update({
                      'biaya': biayaBaru,
                      'diagnosa': diagnosaCtrl.text,
                      'jenis_layanan': layananCtrl.text,
                    })
                    .eq('id', item['id']);
                if (mounted) {
                  Navigator.pop(context); // Tutup dialog
                  Navigator.pop(context); // Tutup modal level 3
                  Navigator.pop(context); // Tutup modal level 2
                  _fetchHistory(); // Refresh
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Data berhasil diperbarui!")),
                  );
                }
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Gagal update: $e")));
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- LEVEL 3: RINCIAN TRANSAKSI ---
  void _showTransactionDetails(
    String peternakName,
    List<Map<String, dynamic>> transactions,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        int total = _calculateSubTotal(transactions);
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peternakName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${transactions.length} Transaksi",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatRupiah(total),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // List
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final trx = transactions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat(
                                      'dd',
                                    ).format(DateTime.parse(trx['waktu'])),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MMM',
                                    ).format(DateTime.parse(trx['waktu'])),
                                    style: GoogleFonts.poppins(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trx['jenis_hewan'] ?? '-',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "Diagnosa: ${trx['diagnosa'] ?? '-'}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    "Layanan: ${trx['jenis_layanan'] ?? '-'}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatRupiahSimple(trx['biaya']),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _editTransaksiDialog(trx),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- LEVEL 2: LIST PETERNAK (FIX ICON + FIX ERROR) ---
  void _showPeternakList(
    String title,
    List<Map<String, dynamic>> allData,
  ) async {
    Map<String, List<Map<String, dynamic>>> groupedByPeternak = {};
    for (var item in allData) {
      String key = item['nama_peternak'] ?? 'Tanpa Nama';
      if (!groupedByPeternak.containsKey(key)) groupedByPeternak[key] = [];
      groupedByPeternak[key]!.add(item);
    }

    Map<String, Map<String, dynamic>> infoPeternak = {};
    try {
      final names = groupedByPeternak.keys.toList();
      if (names.isNotEmpty) {
        // FIX: inFilter (bukan in_)
        final res = await _supabase
            .from('peternak')
            .select()
            .inFilter('nama', names);
        for (var p in res) {
          infoPeternak[p['nama']] = p;
        }
      }
    } catch (e) {
      debugPrint("Gagal fetch info peternak: $e");
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      // FIX: ICON ORANG (Bukan Kotak Obat)
                      CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        child: Icon(Icons.person, color: Colors.blue[700]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              "Daftar Peternak (${groupedByPeternak.length})",
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                // List Peternak
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: groupedByPeternak.keys.length,
                    itemBuilder: (context, index) {
                      String peternakName = groupedByPeternak.keys.elementAt(
                        index,
                      );
                      List<Map<String, dynamic>> transactions =
                          groupedByPeternak[peternakName]!;
                      int subTotal = _calculateSubTotal(transactions);

                      String alamat =
                          infoPeternak[peternakName]?['alamat'] ??
                          'Alamat tidak ditemukan';
                      String hp = infoPeternak[peternakName]?['no_hp'] ?? '-';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          onTap: () => _showTransactionDetails(
                            peternakName,
                            transactions,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.purple[50],
                                  child: Text(
                                    peternakName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        peternakName,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        alamat,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (hp != '-')
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone,
                                              size: 10,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              hp,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatRupiah(subTotal),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      "${transactions.length} Trx",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- EXPORT FUNCTION (SAMA AJA) ---
  Future<void> _saveAndLaunchFile(List<int> bytes, String fileName) async {
    if (kIsWeb) {
      final base64 = base64Encode(bytes);
      String mimeType = fileName.endsWith('.pdf')
          ? 'application/pdf'
          : 'text/csv';
      final anchor = html.AnchorElement(href: 'data:$mimeType;base64,$base64')
        ..target = 'blank';
      anchor.download = fileName;
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } else {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan $fileName');
    }
  }

  Future<void> _exportCsv() async {
    if (_filteredTransaksi.isEmpty) return;
    try {
      List<List<dynamic>> rows = [];
      rows.add([
        "Tanggal",
        "Jam",
        "Dokter",
        "Peternak",
        "Layanan",
        "Diagnosa",
        "Biaya",
      ]);
      for (var item in _filteredTransaksi) {
        rows.add([
          item['waktu'].toString().substring(0, 10),
          _formatJam(item['waktu']),
          item['dokter_email'],
          item['nama_peternak'],
          item['jenis_layanan'],
          item['diagnosa'],
          item['biaya'],
        ]);
      }
      String csvData = const ListToCsvConverter().convert(rows);
      String label = _selectedDateRange == null ? "Semua" : "Custom";
      await _saveAndLaunchFile(utf8.encode(csvData), "Laporan_$label.csv");
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal CSV: $e")));
    }
  }

  Future<void> _exportPdf() async {
    if (_filteredTransaksi.isEmpty) return;
    try {
      final pdf = pw.Document();
      String label = _selectedDateRange == null
          ? "Semua Waktu"
          : "Custom Range";
      final tableData = <List<String>>[
        <String>['Tanggal', 'Peternak', 'Layanan', 'Biaya'],
        ..._filteredTransaksi.map(
          (item) => [
            item['waktu'].toString().substring(0, 10),
            item['nama_peternak']?.toString() ?? '-',
            item['jenis_layanan']?.toString() ?? '-',
            _formatRupiahSimple(item['biaya']),
          ],
        ),
      ];
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "PUSKESWAN TRENGGALEK",
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Laporan Keuangan",
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                  pw.Text(
                    "Periode: $label",
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Divider(),
                ],
              ),
            ),
            pw.TableHelper.fromTextArray(context: context, data: tableData),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Total: ${_formatRupiah(_totalSangu)}",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      await _saveAndLaunchFile(await pdf.save(), "Laporan_Sangu.pdf");
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal PDF: $e")));
    }
  }

  String _formatRupiah(int nominal) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(nominal);
  String _formatRupiahSimple(dynamic nominal) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  ).format(nominal);
  String _formatJam(String isoDate) {
    try {
      return DateFormat('HH:mm').format(DateTime.parse(isoDate));
    } catch (e) {
      return "-";
    }
  }

  void _showExportDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Export Data",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text("Download CSV"),
              onTap: () {
                Navigator.pop(context);
                _exportCsv();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text("Download PDF"),
              onTap: () {
                Navigator.pop(context);
                _exportPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isActive = _activeFilterLabel == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: (val) => _setQuickFilter(label),
        selectedColor: Colors.purple[100],
        checkmarkColor: Colors.purple,
        labelStyle: TextStyle(
          color: isActive ? Colors.purple : Colors.black87,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupData();
    final sortedKeys = groupedData.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Laporan & Sangu",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.purple),
            onPressed: _showExportDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _runSearch,
                  decoration: InputDecoration(
                    hintText: "Cari...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip("Hari Ini"),
                      _buildFilterChip("7 Hari"),
                      _buildFilterChip("Bulan Ini"),
                      _buildFilterChip("Semua"),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: InkWell(
                          onTap: _pickDateRange,
                          child: Chip(
                            avatar: const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text("Custom"),
                            backgroundColor: Colors.purple,
                            labelStyle: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedDateRange != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Filter: ${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // TOTAL CARD
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Pendapatan (Sesuai Filter)",
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatRupiah(_totalSangu),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${_filteredTransaksi.length} Transaksi",
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // LIST DATA
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : sortedKeys.isEmpty
                ? Center(
                    child: Text(
                      "Data Kosong",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedKeys.length,
                    itemBuilder: (context, index) {
                      String groupKey = sortedKeys[index];
                      List<Map<String, dynamic>> transactions =
                          groupedData[groupKey]!;
                      int subTotal = _calculateSubTotal(transactions);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          onTap: () =>
                              _showPeternakList(groupKey, transactions),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // FIX: ICON ORANG (Di Halaman Depan)
                                CircleAvatar(
                                  backgroundColor: Colors.blue[50],
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        groupKey,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        "${transactions.length} Pasien",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatRupiah(subTotal),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ],
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

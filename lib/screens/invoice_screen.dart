import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
  bool _isLoading = true;
  int _totalSangu = 0;
  DateTime? _selectedDate;
  String? _selectedDokterEmail;
  List<String> _dokterList = ['Semua Dokter'];

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
        // Silent error
      }
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final userEmail = _supabase.auth.currentUser?.email;
      var queryBuilder = _supabase.from('pelayanan').select();

      if (_selectedDate != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        queryBuilder = queryBuilder
            .gte('waktu', '$dateStr 00:00:00')
            .lte('waktu', '$dateStr 23:59:59');
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
      final allOffline = await DatabaseHelper().getTransaksiPending();

      List<Map<String, dynamic>> gabungan = [];

      for (var item in allOffline) {
        bool passDate = true;
        bool passDokter = true;

        if (_selectedDate != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
          passDate = item['waktu'].toString().substring(0, 10) == dateStr;
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

      int total = 0;
      for (var item in gabungan) {
        total += (item['biaya'] as num).toInt();
      }

      if (mounted) {
        setState(() {
          _allTransaksi = gabungan;
          _totalSangu = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: "Pilih Tanggal Laporan",
      cancelText: "Semua Waktu",
      confirmText: "Pilih",
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchHistory();
    }
  }

  // --- EXPORT MENU ---
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
              "Export Laporan Keuangan",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: Text("Download CSV (Excel)", style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _exportCsv();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text("Download PDF (Resmi)", style: GoogleFonts.poppins()),
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

  Future<void> _exportCsv() async {
    if (_allTransaksi.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Data kosong!")));
      return;
    }
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
        "Status",
      ]);

      for (var item in _allTransaksi) {
        rows.add([
          item['waktu'].toString().substring(0, 10),
          _formatJam(item['waktu']),
          item['dokter_email'],
          item['nama_peternak'],
          item['jenis_layanan'],
          item['diagnosa'],
          item['biaya'],
          item['status'],
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final dateLabel = _selectedDate == null
          ? "Semua_Waktu"
          : DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final path = "${directory.path}/Laporan_Sangu_$dateLabel.csv";
      final file = File(path);
      await file.writeAsString(csvData);
      await Share.shareXFiles([XFile(path)], text: 'Laporan Keuangan CSV');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal CSV: $e")));
    }
  }

  Future<void> _exportPdf() async {
    if (_allTransaksi.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Data kosong!")));
      return;
    }
    try {
      final pdf = pw.Document();
      final dateLabel = _selectedDate == null
          ? "Semua Waktu"
          : DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate!);

      // FIX TYPE DATA: PASTIKAN List<String>
      final tableData = <List<String>>[
        <String>['Tanggal', 'Peternak', 'Layanan', 'Biaya (Rp)'],
        ..._allTransaksi.map((item) {
          final date = item['waktu'].toString().substring(0, 10);
          return [
            date,
            item['nama_peternak']?.toString() ?? '-',
            item['jenis_layanan']?.toString() ?? '-',
            NumberFormat.currency(
              locale: 'id_ID',
              symbol: '',
              decimalDigits: 0,
            ).format(item['biaya']),
          ];
        }),
      ];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
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
                      "Laporan Pendapatan Pelayanan",
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      "Periode: $dateLabel",
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              // FIX DEPRECATED METHOD
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.purple,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                },
                data: tableData,
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total Pendapatan: ${_formatRupiah(_totalSangu)}",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Footer(
                title: pw.Text(
                  "Generated by Puskeswan App",
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/Laporan_Sangu.pdf";
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(path)], text: 'Laporan Keuangan PDF');
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

  String _formatJam(String isoDate) {
    try {
      return DateFormat('HH:mm').format(DateTime.parse(isoDate));
    } catch (e) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Invoice & Sangu",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
          // FILTER FILTER AREA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.purple),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Filter Tanggal:",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _selectedDate == null
                                    ? "Semua Riwayat"
                                    : DateFormat(
                                        'dd MMMM yyyy',
                                        'id_ID',
                                      ).format(_selectedDate!),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedDate != null)
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() => _selectedDate = null);
                              _fetchHistory();
                            },
                          )
                        else
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                if (widget.role == 'Admin Gudang') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple[100]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDokterEmail ?? 'Semua Dokter',
                        isExpanded: true,
                        icon: const Icon(
                          Icons.person_search,
                          color: Colors.purple,
                        ),
                        items: _dokterList
                            .map(
                              (String value) => DropdownMenuItem(
                                value: value,
                                child: Text(
                                  value == 'Semua Dokter'
                                      ? "Semua Dokter"
                                      : "Dr. ${value.split('@')[0]}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.purple[900],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (newValue) {
                          setState(() => _selectedDokterEmail = newValue);
                          _fetchHistory();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // KARTU TOTAL
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? "Total Pendapatan (Akumulasi)"
                            : "Total Pendapatan Tanggal Ini",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatRupiah(_totalSangu),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${_allTransaksi.length} Data Transaksi",
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
                : _allTransaksi.isEmpty
                ? Center(
                    child: Text(
                      "Data tidak ditemukan",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: _allTransaksi.length,
                    itemBuilder: (context, index) {
                      final item = _allTransaksi[index];
                      final isOffline = item['status'] == 'offline';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[100]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isOffline
                                    ? Colors.orange[50]
                                    : Colors.purple[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isOffline ? Icons.wifi_off : Icons.pets,
                                color: isOffline
                                    ? Colors.orange
                                    : Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['nama_peternak'] ?? '-',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "${item['jenis_hewan']} • ${item['jenis_layanan']}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (widget.role == 'Admin Gudang')
                                    Text(
                                      "Dr. ${item['dokter_email']?.split('@')[0]}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.purple,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatRupiah((item['biaya'] as num).toInt()),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  item['waktu'].toString().substring(0, 10),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey,
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
      ),
    );
  }
}

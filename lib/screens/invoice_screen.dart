import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceScreen extends StatefulWidget {
  final String role;
  const InvoiceScreen({super.key, required this.role});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _dataTransaksi = [];
  int _totalPendapatan = 0;

  String _filterWaktu = 'Hari Ini';
  String? _filterDokter;
  List<String> _listDokter = [];

  @override
  void initState() {
    super.initState();
    _ambilDataTransaksi();
  }

  Future<void> _ambilDataTransaksi() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;

      var query = _supabase.from('pelayanan').select();

      if (widget.role != 'Admin Gudang') {
        query = query.eq('dokter_email', user?.email ?? '');
      }

      final response = await query.order('waktu', ascending: false);
      _prosesData(response);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  void _prosesData(List<dynamic> dataMentah) {
    List<Map<String, dynamic>> semuaData = List<Map<String, dynamic>>.from(
      dataMentah,
    );

    if (widget.role == 'Admin Gudang') {
      final emails = semuaData
          .map((e) => e['dokter_email'].toString())
          .toSet()
          .toList();
      _listDokter = emails;
    }

    final hariIni = DateTime.now().toString().substring(0, 10);

    List<Map<String, dynamic>> dataTersaring = semuaData.where((item) {
      final waktu = item['waktu'].toString().substring(0, 10);
      final dokter = item['dokter_email'].toString();

      bool passWaktu = (_filterWaktu == 'Hari Ini') ? (waktu == hariIni) : true;
      bool passDokter = (_filterDokter == null)
          ? true
          : (dokter == _filterDokter);

      return passWaktu && passDokter;
    }).toList();

    int total = 0;
    for (var item in dataTersaring) {
      total += (item['biaya'] as int);
    }

    if (mounted) {
      setState(() {
        _dataTransaksi = dataTersaring;
        _totalPendapatan = total;
        _isLoading = false;
      });
    }
  }

  // --- FUNGSI CETAK PDF (FITUR BARU) ---
  Future<void> _cetakLaporan() async {
    final doc = pw.Document();

    // Buat Data Tabel PDF
    final dataTabel = _dataTransaksi.map((item) {
      final tgl = item['waktu']
          .toString()
          .substring(0, 16)
          .replaceAll('T', ' ');
      return [
        tgl,
        item['nama_peternak'],
        "${item['jenis_hewan']} (${item['diagnosa']})",
        item['jenis_layanan'],
        "Rp ${item['biaya']}",
      ];
    }).toList();

    // Desain Halaman PDF
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "Laporan Puskeswan",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Periode: $_filterWaktu"),
              pw.Text("Dokter: ${_filterDokter ?? 'Semua Dokter'}"),
              pw.Text("Dicetak oleh: ${widget.role}"),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Tabel Data
              pw.TableHelper.fromTextArray(
                headers: ['Waktu', 'Peternak', 'Pasien', 'Tindakan', 'Biaya'],
                data: dataTabel,
                border: null,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300),
                  ),
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
              ),

              pw.SizedBox(height: 20),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total Pendapatan: Rp $_totalPendapatan",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Tampilkan Preview Print
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.role == 'Admin Gudang' ? "Pantau Setoran" : "Pendapatan Saya",
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // TOMBOL PRINT (BARU)
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: "Cetak Laporan",
            onPressed: _dataTransaksi.isEmpty ? null : _cetakLaporan,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _filterWaktu = value);
              _ambilDataTransaksi();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Hari Ini', child: Text("Hari Ini")),
              const PopupMenuItem(value: 'Semua', child: Text("Semua Riwayat")),
            ],
            icon: const Icon(Icons.calendar_today),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.role == 'Admin Gudang' && _listDokter.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.teal[50],
              child: Row(
                children: [
                  const Text(
                    "Filter Dokter: ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _filterDokter,
                      hint: const Text("Semua Dokter"),
                      underline: Container(height: 1, color: Colors.teal),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("Semua Dokter"),
                        ),
                        ..._listDokter.map(
                          (e) => DropdownMenuItem(value: e, child: Text(e)),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _filterDokter = val;
                        });
                        _ambilDataTransaksi();
                      },
                    ),
                  ),
                ],
              ),
            ),

          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.teal.withValues(alpha: 0.3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Total Pendapatan ($_filterWaktu)",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  "Rp $_totalPendapatan",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_filterDokter != null)
                  Text(
                    "(Oleh: $_filterDokter)",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dataTransaksi.isEmpty
                ? const Center(child: Text("Belum ada data."))
                : ListView.builder(
                    itemCount: _dataTransaksi.length,
                    itemBuilder: (context, index) {
                      final item = _dataTransaksi[index];
                      final tgl = item['waktu']
                          .toString()
                          .substring(0, 16)
                          .replaceAll('T', ' ');
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal[100],
                            child: Text(
                              item['nama_peternak'][0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item['nama_peternak'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${item['jenis_hewan']} (${item['diagnosa']})\n$tgl",
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Rp ${item['biaya']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.teal,
                                ),
                              ),
                              Text(
                                item['jenis_layanan'],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
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

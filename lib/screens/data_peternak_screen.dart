import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'detail_peternak_screen.dart';

class DataPeternakScreen extends StatefulWidget {
  final String role;
  const DataPeternakScreen({super.key, required this.role});

  @override
  State<DataPeternakScreen> createState() => _DataPeternakScreenState();
}

class _DataPeternakScreenState extends State<DataPeternakScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _peternakList = [];
  List<Map<String, dynamic>> _filteredList = [];
  final TextEditingController _searchController = TextEditingController();

  final Map<String, List<String>> _dataWilayah = {
    'Pogalan': [
      'Ngetal',
      'Pogalan',
      'Ngadirenggo',
      'Bendorejo',
      'Kedunglurah',
      'Wonocoyo',
    ],
    'Gandusari': [
      'Gandusari',
      'Sukorejo',
      'Wonoanti',
      'Widoro',
      'Karanganyar',
      'Melis',
    ],
    'Trenggalek': [
      'Surodakan',
      'Sumbergedong',
      'Kelutan',
      'Ngantru',
      'Tamanan',
      'Karangsoko',
    ],
    'Durenan': ['Durenan', 'Pandean', 'Kendalrejo', 'Semarum', 'Malasan'],
    'Karangan': ['Karangan', 'Salamrejo', 'Buluerjo', 'Ngentrong'],
    'Tugu': ['Nglongsor', 'Dermosari', 'Pucanganak', 'Gondang'],
  };

  @override
  void initState() {
    super.initState();
    _fetchPeternak();
  }

  Future<void> _fetchPeternak() async {
    try {
      final data = await _supabase.from('peternak').select().order('nama');
      if (mounted) {
        setState(() {
          _peternakList = List<Map<String, dynamic>>.from(data);
          _filteredList = _peternakList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterPeternak(String query) {
    setState(() {
      _filteredList = _peternakList.where((item) {
        final nama = item['nama'].toString().toLowerCase();
        final desa = item['desa']?.toString().toLowerCase() ?? '';
        return nama.contains(query.toLowerCase()) ||
            desa.contains(query.toLowerCase());
      }).toList();
    });
  }

  // --- EXPORT LOGIC ---
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
              "Export Data Peternak",
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
              title: Text(
                "Download PDF (Laporan)",
                style: GoogleFonts.poppins(),
              ),
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
    try {
      List<List<dynamic>> rows = [];
      rows.add(["No", "Nama Lengkap", "Desa", "Kecamatan", "RT", "No HP"]);

      int i = 1;
      for (var item in _filteredList) {
        rows.add([
          i++,
          item['nama'],
          item['desa'] ?? '-',
          item['kecamatan'] ?? '-',
          item['rt'] ?? '-',
          item['no_hp'] ?? '-',
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/Data_Peternak_Trenggalek.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      // Share File
      await Share.shareXFiles([XFile(path)], text: 'Data Peternak CSV');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal CSV: $e")));
    }
  }

  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document();

      // Menyiapkan Data Tabel (FIX TYPE ERROR)
      final tableData = <List<String>>[
        ['No', 'Nama Peternak', 'Alamat Lengkap', 'No HP'], // Header
        ..._filteredList.map((item) {
          final index = (_filteredList.indexOf(item) + 1).toString();
          final alamat =
              "Ds. ${item['desa'] ?? '-'} RT ${item['rt'] ?? '-'}, Kec. ${item['kecamatan'] ?? '-'}";
          return [
            index,
            item['nama'].toString(),
            alamat,
            item['no_hp']?.toString() ?? '-',
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
                      "DINAS PETERNAKAN KAB. TRENGGALEK",
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "Laporan Data Peternak Binaan",
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              // FIX DEPRECATED & TYPE ERROR
              pw.TableHelper.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.purple,
                ),
                data: tableData,
              ),
              pw.SizedBox(height: 20),
              pw.Footer(
                title: pw.Text(
                  "Generated by Puskeswan App (Vixel Creative)",
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
      final path = "${directory.path}/Laporan_Peternak.pdf";
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(path)], text: 'Laporan Data Peternak PDF');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal PDF: $e")));
    }
  }

  // --- DIALOG CRUD ---
  Future<void> _showFormDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final namaCtrl = TextEditingController(text: item?['nama'] ?? '');
    final rtCtrl = TextEditingController(text: item?['rt'] ?? '');
    final hpCtrl = TextEditingController(text: item?['no_hp'] ?? '');
    String? selectedKecamatan = item?['kecamatan'];
    String? selectedDesa = item?['desa'];

    if (selectedKecamatan != null &&
        !_dataWilayah.containsKey(selectedKecamatan)) {
      selectedKecamatan = null;
      selectedDesa = null;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(
              isEdit ? "Edit Peternak" : "Peternak Baru",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaCtrl,
                    decoration: _inputDecor("Nama Lengkap"),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: _inputDecor("Kecamatan"),
                    value: selectedKecamatan,
                    hint: const Text("Pilih Kecamatan"),
                    items: _dataWilayah.keys
                        .map(
                          (kec) =>
                              DropdownMenuItem(value: kec, child: Text(kec)),
                        )
                        .toList(),
                    onChanged: (val) {
                      setStateSB(() {
                        selectedKecamatan = val;
                        selectedDesa = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: _inputDecor("Desa"),
                    value: selectedDesa,
                    hint: Text(
                      selectedKecamatan == null
                          ? "Pilih Kecamatan dulu"
                          : "Pilih Desa",
                    ),
                    items: selectedKecamatan == null
                        ? []
                        : _dataWilayah[selectedKecamatan]!
                              .map(
                                (desa) => DropdownMenuItem(
                                  value: desa,
                                  child: Text(desa),
                                ),
                              )
                              .toList(),
                    onChanged: selectedKecamatan == null
                        ? null
                        : (val) => setStateSB(() => selectedDesa = val),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecor("RT (Angka)"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hpCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecor("No HP"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (namaCtrl.text.isEmpty) return;

                  // Simpan context sebelum async gap
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);

                  final data = {
                    'nama': namaCtrl.text,
                    'kecamatan': selectedKecamatan,
                    'desa': selectedDesa,
                    'rt': rtCtrl.text,
                    'no_hp': hpCtrl.text,
                    'alamat':
                        "$selectedDesa RT ${rtCtrl.text}, $selectedKecamatan",
                  };
                  try {
                    if (isEdit) {
                      await _supabase
                          .from('peternak')
                          .update(data)
                          .eq('id', item['id']);
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text("Data Terupdate!")),
                      );
                    } else {
                      await _supabase.from('peternak').insert(data);
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text("Peternak Ditambah!")),
                      );
                    }

                    navigator.pop();
                    _fetchPeternak();
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text("Gagal: $e")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Simpan"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deletePeternak(int id) async {
    await _supabase.from('peternak').delete().eq('id', id);
    _fetchPeternak();
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Data Peternak",
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              onChanged: _filterPeternak,
              decoration: InputDecoration(
                hintText: "Cari nama atau desa...",
                prefixIcon: const Icon(Icons.search, color: Colors.purple),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredList.isEmpty
                ? Center(
                    child: Text(
                      "Data kosong",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredList[index];
                      final alamatFix = item['desa'] != null
                          ? "Ds. ${item['desa']}, Kec. ${item['kecamatan']}"
                          : (item['alamat'] ?? '-');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple[50],
                            child: Text(
                              item['nama'][0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            item['nama'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            alamatFix,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: PopupMenuButton(
                            onSelected: (val) {
                              if (val == 'edit') _showFormDialog(item: item);
                              if (val == 'delete') _deletePeternak(item['id']);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text("Edit"),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Hapus",
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  DetailPeternakScreen(peternak: item),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

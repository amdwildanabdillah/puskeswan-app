import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DetailPeternakScreen extends StatefulWidget {
  final Map<String, dynamic> peternak; // Data peternak dari halaman sebelumnya
  const DetailPeternakScreen({super.key, required this.peternak});

  @override
  State<DetailPeternakScreen> createState() => _DetailPeternakScreenState();
}

class _DetailPeternakScreenState extends State<DetailPeternakScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _listHewan = [];
  List<Map<String, dynamic>> _listRiwayat = [];
  bool _isLoading = true;

  // Master Data Lokal buat Dropdown Hewan
  List<String> _bangsaList = [
    'Limosin',
    'Simental',
    'PO',
    'Brahman',
    'Jawa',
    'PE',
    'Senduro',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDetailData();
    _fetchMasterBangsa(); // Cek kalau ada bangsa baru di server
  }

  Future<void> _fetchMasterBangsa() async {
    try {
      final data = await _supabase.from('master_bangsa').select('nama_bangsa');
      if (mounted) {
        setState(() {
          final serverList = List<String>.from(
            data.map((e) => e['nama_bangsa']),
          );
          _bangsaList = {..._bangsaList, ...serverList}.toList();
        });
      }
    } catch (e) {}
  }

  Future<void> _fetchDetailData() async {
    try {
      final peternakId = widget.peternak['id'];
      final peternakNama = widget.peternak['nama'];

      // 1. AMBIL DATA HEWAN
      final dataHewan = await _supabase
          .from('hewan')
          .select()
          .eq('peternak_id', peternakId)
          .order('created_at', ascending: false);

      // 2. AMBIL RIWAYAT PELAYANAN
      final dataRiwayat = await _supabase
          .from('pelayanan')
          .select()
          .eq('nama_peternak', peternakNama)
          .order('waktu', ascending: false);

      if (mounted) {
        setState(() {
          _listHewan = List<Map<String, dynamic>>.from(dataHewan);
          _listRiwayat = List<Map<String, dynamic>>.from(dataRiwayat);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- POPUP TAMBAH HEWAN (KHUSUS PETERNAK INI) ---
  Future<void> _showAddHewanDialog() async {
    String? jenis;
    String? bangsa;
    final kodeCtrl = TextEditingController();
    final ciriCtrl = TextEditingController();
    final newJenisCtrl = TextEditingController();
    final newBangsaCtrl = TextEditingController();

    List<String> localJenisList = ['Sapi', 'Kambing', 'Domba'];
    List<String> localBangsaList = List.from(_bangsaList);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(
              "Tambah Hewan",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DROPDOWN JENIS
                  DropdownButtonFormField<String>(
                    value: jenis,
                    decoration: _inputDecor("Jenis Hewan"),
                    hint: const Text("Pilih Jenis"),
                    items: [
                      ...localJenisList.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e)),
                      ),
                      const DropdownMenuItem(
                        value: 'ADD_NEW',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: Colors.purple),
                            Text(
                              " Lainnya...",
                              style: TextStyle(color: Colors.purple),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == 'ADD_NEW') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Jenis Hewan Baru"),
                            content: TextField(
                              controller: newJenisCtrl,
                              decoration: _inputDecor("Nama Jenis"),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  if (newJenisCtrl.text.isNotEmpty) {
                                    setStateSB(() {
                                      localJenisList.add(newJenisCtrl.text);
                                      jenis = newJenisCtrl.text;
                                    });
                                    Navigator.pop(ctx);
                                  }
                                },
                                child: const Text("Tambah"),
                              ),
                            ],
                          ),
                        );
                      } else {
                        setStateSB(() => jenis = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // DROPDOWN BANGSA
                  DropdownButtonFormField<String>(
                    value: bangsa,
                    decoration: _inputDecor("Bangsa / Ras"),
                    hint: const Text("Pilih Ras"),
                    items: [
                      ...localBangsaList.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e)),
                      ),
                      const DropdownMenuItem(
                        value: 'ADD_NEW',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: Colors.purple),
                            Text(
                              " Tambah Ras...",
                              style: TextStyle(color: Colors.purple),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == 'ADD_NEW') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Tambah Ras Baru"),
                            content: TextField(
                              controller: newBangsaCtrl,
                              decoration: _inputDecor("Nama Ras"),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  if (newBangsaCtrl.text.isNotEmpty) {
                                    try {
                                      _supabase.from('master_bangsa').insert({
                                        'nama_bangsa': newBangsaCtrl.text,
                                      });
                                    } catch (e) {}
                                    setStateSB(() {
                                      localBangsaList.add(newBangsaCtrl.text);
                                      bangsa = newBangsaCtrl.text;
                                    });
                                    Navigator.pop(ctx);
                                  }
                                },
                                child: const Text("Tambah"),
                              ),
                            ],
                          ),
                        );
                      } else {
                        setStateSB(() => bangsa = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: kodeCtrl,
                    decoration: _inputDecor("Kode Anting / Nama"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ciriCtrl,
                    decoration: _inputDecor("Ciri-ciri (Opsional)"),
                  ),
                  const SizedBox(height: 10),

                  // TAMBAHAN UI FOTO (PAJANGAN)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          color: Colors.grey,
                          size: 30,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Upload Foto (Opsional)",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
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
                  if (kodeCtrl.text.isEmpty || jenis == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Jenis & Identitas Wajib Diisi!"),
                      ),
                    );
                    return;
                  }
                  try {
                    // Simpan langsung pake ID Peternak
                    await _supabase.from('hewan').insert({
                      'peternak_id': widget.peternak['id'],
                      'jenis': jenis,
                      'bangsa': bangsa,
                      'kode_anting': kodeCtrl.text,
                      'ciri_ciri': ciriCtrl.text,
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      _fetchDetailData(); // Refresh List Hewan
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Hewan Berhasil Ditambah!"),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
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

  InputDecoration _inputDecor(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  String _formatTanggal(String isoDate) {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(isoDate));
    } catch (e) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.peternak;
    final alamatFix = p['desa'] != null
        ? "Ds. ${p['desa']} RT ${p['rt'] ?? '-'}, Kec. ${p['kecamatan'] ?? '-'}"
        : (p['alamat'] ?? '-');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Detail Peternak",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // HEADER PROFIL
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(20),
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
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Text(
                    p['nama'][0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['nama'],
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alamatFix,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            p['no_hp'] ?? '-',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // TAB BAR
          TabBar(
            controller: _tabController,
            labelColor: Colors.purple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.purple,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: "Hewan Ternak"),
              Tab(text: "Riwayat Medis"),
            ],
          ),

          // TAB CONTENT
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: LIST HEWAN
                      _listHewan.isEmpty
                          ? Center(
                              child: Text(
                                "Belum ada data hewan",
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _listHewan.length,
                              itemBuilder: (context, index) {
                                final h = _listHewan[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.pets,
                                          color: Colors.orange[800],
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "${h['jenis']} - ${h['bangsa'] ?? 'Umum'}",
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              "Kode: ${h['kode_anting']}",
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            if (h['ciri_ciri'] != null &&
                                                h['ciri_ciri'] != '')
                                              Text(
                                                "Ciri: ${h['ciri_ciri']}",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                      // TAB 2: RIWAYAT MEDIS
                      _listRiwayat.isEmpty
                          ? Center(
                              child: Text(
                                "Belum ada riwayat medis",
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _listRiwayat.length,
                              itemBuilder: (context, index) {
                                final r = _listRiwayat[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatTanggal(r['waktu']),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  r['kategori_layanan'] ==
                                                      'IB (Inseminasi)'
                                                  ? Colors.blue[50]
                                                  : Colors.green[50],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              r['kategori_layanan'] ??
                                                  'Pengobatan',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        r['diagnosa'] ?? '-',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        "Tindakan: ${r['jenis_layanan']}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (r['obat_1'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            "Obat: ${r['obat_1']}, ${r['obat_2'] ?? ''}",
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),

      // TOMBOL TAMBAH HEWAN (BARU)
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHewanDialog,
        backgroundColor: Colors.purple,
        tooltip: "Tambah Hewan",
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

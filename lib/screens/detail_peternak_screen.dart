import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DetailPeternakScreen extends StatefulWidget {
  final Map<String, dynamic> peternak;
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

  // List Master Data (Sama kayak di Input Pelayanan)
  List<String> _jenisList = ['Sapi', 'Kambing', 'Domba'];
  List<String> _bangsaList = ['Limosin', 'Simental', 'PO', 'Brahman', 'Jawa'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDetailData();
  }

  Future<void> _fetchDetailData() async {
    try {
      final peternakId = widget.peternak['id'];

      // 1. AMBIL HEWAN (FILTER STATUS 'Aktif')
      final dataHewan = await _supabase
          .from('hewan')
          .select()
          .eq('peternak_id', peternakId)
          .eq('status', 'Aktif')
          .order('created_at', ascending: false);

      // 2. AMBIL RIWAYAT
      final dataRiwayat = await _supabase
          .from('pelayanan')
          .select()
          .eq('nama_peternak', widget.peternak['nama'])
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

  // --- POPUP KECIL BUAT NAMBAH TEXT MANUAL (DIAGNOSA/RAS) ---
  Future<void> _showTextInputDialog(
    String title,
    Function(String) onSave,
  ) async {
    final txtCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: txtCtrl,
          decoration: _inputDecor("Ketik nama baru..."),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (txtCtrl.text.isNotEmpty) {
                onSave(txtCtrl.text);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- ADD HEWAN DIALOG (VERSI SINKRON DENGAN INPUT PELAYANAN) ---
  Future<void> _showAddHewanDialog() async {
    String? selectedJenis;
    String? selectedBangsa;
    final kodeCtrl = TextEditingController();
    final ciriCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // PENTING: Biar dropdown bisa update state dalam dialog
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              "Tambah Hewan Baru",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. DROPDOWN JENIS (Plus Logic Lainnya)
                  DropdownButtonFormField<String>(
                    initialValue: selectedJenis,
                    decoration: _inputDecor("Jenis Hewan"),
                    hint: const Text("Pilih Jenis"),
                    items: [
                      ..._jenisList.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e)),
                      ),
                      const DropdownMenuItem(
                        value: 'NEW',
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
                      if (val == 'NEW') {
                        _showTextInputDialog("Jenis Hewan Baru", (text) {
                          setStateDialog(() {
                            _jenisList.add(text); // Tambah ke list sementara
                            selectedJenis = text; // Auto select
                          });
                        });
                      } else {
                        setStateDialog(() => selectedJenis = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // 2. DROPDOWN BANGSA (Plus Logic Tambah)
                  DropdownButtonFormField<String>(
                    initialValue: selectedBangsa,
                    decoration: _inputDecor("Bangsa / Ras"),
                    hint: const Text("Pilih Ras"),
                    items: [
                      ..._bangsaList.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e)),
                      ),
                      const DropdownMenuItem(
                        value: 'NEW',
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
                      if (val == 'NEW') {
                        _showTextInputDialog("Nama Ras Baru", (text) {
                          setStateDialog(() {
                            _bangsaList.add(text);
                            selectedBangsa = text;
                          });
                        });
                      } else {
                        setStateDialog(() => selectedBangsa = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // 3. INPUT TEXT BIASA
                  TextField(
                    controller: kodeCtrl,
                    decoration: _inputDecor("Kode / Nama Hewan"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ciriCtrl,
                    decoration: _inputDecor("Ciri-ciri (Warna, dll)"),
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
                  if (selectedJenis == null || kodeCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Jenis & Nama wajib diisi!"),
                      ),
                    );
                    return;
                  }
                  try {
                    await _supabase.from('hewan').insert({
                      'peternak_id': widget.peternak['id'],
                      'jenis': selectedJenis,
                      'bangsa': selectedBangsa,
                      'kode_anting': kodeCtrl.text,
                      'ciri_ciri': ciriCtrl.text,
                      'status': 'Aktif',
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      _fetchDetailData(); // Refresh list utama
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Hewan berhasil ditambah!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Gagal: $e"),
                        backgroundColor: Colors.red,
                      ),
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

  // --- EDIT HEWAN DIALOG ---
  Future<void> _editHewanDialog(Map<String, dynamic> hewan) async {
    final kodeCtrl = TextEditingController(text: hewan['kode_anting']);
    final ciriCtrl = TextEditingController(text: hewan['ciri_ciri']);
    String jenis = hewan['jenis'] ?? 'Sapi';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Edit Hewan",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _jenisList.contains(jenis) ? jenis : null,
              hint: Text(jenis), // Fallback kalau jenis lama ga ada di list
              items: _jenisList
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => jenis = val!,
              decoration: _inputDecor("Jenis"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: kodeCtrl,
              decoration: _inputDecor("Kode / Nama"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ciriCtrl,
              decoration: _inputDecor("Ciri-ciri"),
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
              await _supabase
                  .from('hewan')
                  .update({
                    'jenis': jenis,
                    'kode_anting': kodeCtrl.text,
                    'ciri_ciri': ciriCtrl.text,
                  })
                  .eq('id', hewan['id']);
              Navigator.pop(context);
              _fetchDetailData();
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // --- SOFT DELETE ---
  Future<void> _deleteHewan(int id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Hewan?"),
        content: const Text(
          "Hewan akan ditandai sebagai 'Nonaktif' (Dijual/Mati). Riwayat medis tetap aman.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('hewan').update({'status': 'Nonaktif'}).eq('id', id);
      _fetchDetailData();
    }
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[50], // Style konsisten dengan input pelayanan
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.peternak['nama'],
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
          // Header Profil
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(16),
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
                    widget.peternak['nama'][0].toUpperCase(),
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
                        widget.peternak['nama'],
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.peternak['alamat'] ?? "-",
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                      if (widget.peternak['no_hp'] != null)
                        Text(
                          widget.peternak['no_hp'],
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabController,
            labelColor: Colors.purple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.purple,
            tabs: const [
              Tab(text: "Hewan Ternak"),
              Tab(text: "Riwayat Medis"),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: LIST HEWAN
                _listHewan.isEmpty
                    ? Center(
                        child: Text(
                          "Belum ada hewan aktif",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _listHewan.length,
                        itemBuilder: (ctx, i) {
                          final h = _listHewan[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.pets,
                                  color: Colors.orange,
                                ),
                              ),
                              title: Text(
                                "${h['jenis']} - ${h['kode_anting']}",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (h['bangsa'] != null)
                                    Text(
                                      h['bangsa'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  Text(
                                    h['ciri_ciri'] ?? '-',
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (v) => v == 'edit'
                                    ? _editHewanDialog(h)
                                    : _deleteHewan(h['id']),
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
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
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text("Hapus"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                // TAB 2: RIWAYAT
                _listRiwayat.isEmpty
                    ? Center(
                        child: Text(
                          "Belum ada riwayat",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _listRiwayat.length,
                        itemBuilder: (ctx, i) {
                          final r = _listRiwayat[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                r['diagnosa'] ?? '-',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(DateTime.parse(r['waktu'])),
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                  Text(
                                    "Tindakan: ${r['jenis_layanan'] ?? '-'}",
                                    style: GoogleFonts.poppins(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                "Rp ${r['biaya']}",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      // --- TOMBOL TAMBAH (+) ---
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHewanDialog,
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class GudangScreen extends StatefulWidget {
  final String role;
  const GudangScreen({super.key, required this.role});

  @override
  State<GudangScreen> createState() => _GudangScreenState();
}

class _GudangScreenState extends State<GudangScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _barangList = [];
  List<Map<String, dynamic>> _filteredList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBarang();
  }

  Future<void> _fetchBarang() async {
    try {
      // Ambil semua barang tanpa filter jenis, biar gudang tetap lengkap
      final data = await _supabase.from('barang').select().order('nama_barang');
      if (mounted) {
        setState(() {
          _barangList = List<Map<String, dynamic>>.from(data);
          _filteredList = _barangList; // Awalnya tampilkan semua
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterBarang(String query) {
    setState(() {
      _filteredList = _barangList
          .where(
            (item) => item['nama_barang'].toString().toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    });
  }

  // --- POPUP TRANSAKSI STOK (MASUK/KELUAR) ---
  Future<void> _showStokDialog(Map<String, dynamic> item, bool isMasuk) async {
    final qtyController = TextEditingController();
    final picController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isMasuk ? "Restock Barang" : "Ambil Barang",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isMasuk ? Colors.green : Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Barang: ${item['nama_barang']}",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Jumlah ${isMasuk ? 'Masuk' : 'Keluar'}",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: picController,
              decoration: InputDecoration(
                labelText: isMasuk
                    ? "Diterima Oleh (Nama)"
                    : "Diambil Oleh (Nama)",
                hintText: "Contoh: Dr. Wildan",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
              if (qtyController.text.isEmpty || picController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Jumlah & Nama Wajib Diisi!")),
                );
                return;
              }

              int qty = int.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) return;

              if (!isMasuk && qty > item['stok']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Stok tidak cukup!")),
                );
                return;
              }

              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                int stokBaru = isMasuk
                    ? (item['stok'] + qty)
                    : (item['stok'] - qty);

                // 1. Update Stok Barang
                await _supabase
                    .from('barang')
                    .update({'stok': stokBaru})
                    .eq('id', item['id']);

                // 2. Catat Riwayat (Opsional, silent fail kalau tabel belum ada)
                try {
                  await _supabase.from('riwayat_stok').insert({
                    'barang_id': item['id'],
                    'jenis_transaksi': isMasuk ? 'Masuk' : 'Keluar',
                    'jumlah': qty,
                    'pic_nama': picController.text,
                    'waktu': DateTime.now().toIso8601String(),
                  });
                } catch (_) {}

                await _fetchBarang();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Stok Berhasil ${isMasuk ? 'Ditambah' : 'Dikurangi'}!",
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Gagal update: $e")));
                }
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isMasuk ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isMasuk ? "Simpan Masuk" : "Simpan Keluar"),
          ),
        ],
      ),
    );
  }

  // --- POPUP TAMBAH BARANG BARU (REVISI: ADA JENIS) ---
  Future<void> _showAddBarangDialog() async {
    final namaCtrl = TextEditingController();
    final stokCtrl = TextEditingController();
    final satuanCtrl = TextEditingController();

    // Default jenis
    String selectedJenis = 'Obat';
    final List<String> jenisOptions = ['Obat', 'Pakan', 'Alkes', 'Lainnya'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // Pakai StatefulBuilder biar dropdown bisa ganti value
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              "Barang Baru",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              // Biar gak overflow di HP kecil
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaCtrl,
                    decoration: const InputDecoration(labelText: "Nama Barang"),
                  ),
                  const SizedBox(height: 10),

                  // REVISI: DROPDOWN JENIS BARANG
                  DropdownButtonFormField<String>(
                    initialValue: selectedJenis,
                    decoration: const InputDecoration(
                      labelText: "Jenis Barang",
                    ),
                    items: jenisOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      setStateDialog(() => selectedJenis = val!);
                    },
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: stokCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Stok Awal"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: satuanCtrl,
                    decoration: const InputDecoration(
                      labelText: "Satuan (Botol/Pcs/Zak)",
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
                  if (namaCtrl.text.isEmpty) return;

                  try {
                    await _supabase.from('barang').insert({
                      'nama_barang': namaCtrl.text,
                      'jenis': selectedJenis, // Simpan jenis ke DB
                      'stok': int.tryParse(stokCtrl.text) ?? 0,
                      'satuan': satuanCtrl.text,
                    });

                    Navigator.pop(context);
                    _fetchBarang(); // Refresh list gudang

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Barang baru berhasil ditambahkan!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Gagal tambah: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text("Simpan"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Stok Gudang",
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              onChanged: _filterBarang,
              decoration: InputDecoration(
                hintText: "Cari barang...",
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredList[index];
                      final stok = item['stok'] as int;
                      final jenis = item['jenis'] ?? '-';
                      final isLow = stok < 5;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLow
                                ? Colors.red.withOpacity(0.3)
                                : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isLow
                                    ? Colors.red[50]
                                    : (jenis == 'Obat'
                                          ? Colors.blue[50]
                                          : Colors.orange[50]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                jenis == 'Obat'
                                    ? Icons.medication
                                    : (jenis == 'Pakan'
                                          ? Icons.grass
                                          : Icons.inventory_2),
                                color: isLow
                                    ? Colors.red
                                    : (jenis == 'Obat'
                                          ? Colors.blue
                                          : Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['nama_barang'],
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Tampilkan Jenis & Stok
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          jenis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "$stok ${item['satuan'] ?? 'Pcs'}",
                                        style: GoogleFonts.poppins(
                                          color: isLow
                                              ? Colors.red
                                              : Colors.grey,
                                          fontWeight: isLow
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _showStokDialog(item, false),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.green,
                              ),
                              onPressed: () => _showStokDialog(item, true),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBarangDialog,
        backgroundColor: const Color.fromARGB(255, 149, 33, 243),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

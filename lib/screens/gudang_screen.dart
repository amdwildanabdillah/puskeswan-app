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
      final data = await _supabase.from('barang').select().order('nama_barang');
      if (mounted) {
        setState(() {
          _barangList = List<Map<String, dynamic>>.from(data);
          _filteredList = _barangList;
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

  // --- POPUP TRANSAKSI STOK (MASUK/KELUAR + PIC) ---
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

              // Cek stok cukup gak kalau keluar
              if (!isMasuk && qty > item['stok']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Stok tidak cukup!")),
                );
                return;
              }

              Navigator.pop(context);
              setState(() => _isLoading = true);

              try {
                // 1. Update Stok di Tabel Barang
                int stokBaru = isMasuk
                    ? (item['stok'] + qty)
                    : (item['stok'] - qty);
                await _supabase
                    .from('barang')
                    .update({'stok': stokBaru})
                    .eq('id', item['id']);

                // 2. Catat di Riwayat (Log) - Pastikan tabel riwayat_stok sudah dibuat di SQL Supabase
                try {
                  await _supabase.from('riwayat_stok').insert({
                    'barang_id': item['id'],
                    'jenis_transaksi': isMasuk ? 'Masuk' : 'Keluar',
                    'jumlah': qty,
                    'pic_nama': picController.text,
                    'waktu': DateTime.now().toIso8601String(),
                  });
                } catch (e) {
                  // Silent fail kalau tabel log belum ada, yang penting stok update
                }

                await _fetchBarang();
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Stok Berhasil ${isMasuk ? 'Ditambah' : 'Dikurangi'}!",
                      ),
                    ),
                  );
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Gagal update: $e")));
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

  // --- POPUP TAMBAH BARANG BARU ---
  Future<void> _showAddBarangDialog() async {
    final namaCtrl = TextEditingController();
    final stokCtrl = TextEditingController();
    final satuanCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Barang Baru",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: namaCtrl,
              decoration: const InputDecoration(labelText: "Nama Barang"),
            ),
            TextField(
              controller: stokCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Stok Awal"),
            ),
            TextField(
              controller: satuanCtrl,
              decoration: const InputDecoration(
                labelText: "Satuan (Botol/Pcs)",
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (namaCtrl.text.isEmpty) return;
              await _supabase.from('barang').insert({
                'nama_barang': namaCtrl.text,
                'stok': int.tryParse(stokCtrl.text) ?? 0,
                'satuan': satuanCtrl.text,
              });
              Navigator.pop(context);
              _fetchBarang();
            },
            child: const Text("Simpan"),
          ),
        ],
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
                hintText: "Cari obat/alkes...",
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
                                color: isLow ? Colors.red[50] : Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.inventory_2,
                                color: isLow ? Colors.red : Colors.blue,
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
                                  Text(
                                    "$stok ${item['satuan'] ?? 'Pcs'}",
                                    style: GoogleFonts.poppins(
                                      color: isLow ? Colors.red : Colors.grey,
                                      fontWeight: isLow
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // TOMBOL KURANG (AMBIL)
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _showStokDialog(item, false),
                            ),
                            // TOMBOL TAMBAH (RESTOCK)
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
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

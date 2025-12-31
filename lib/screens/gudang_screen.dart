import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GudangScreen extends StatefulWidget {
  final String role; // Biar tau siapa yang ngambil
  const GudangScreen({super.key, required this.role});

  @override
  State<GudangScreen> createState() => _GudangScreenState();
}

class _GudangScreenState extends State<GudangScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _barangList = [];
  List<Map<String, dynamic>> _filteredList = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBarang();
  }

  // 1. Ambil Data Barang
  Future<void> _fetchBarang() async {
    try {
      final data = await _supabase
          .from('barang')
          .select()
          .order('nama_barang', ascending: true);

      setState(() {
        _barangList = List<Map<String, dynamic>>.from(data);
        _filteredList = _barangList;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // 2. Fungsi Cari Barang
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

  // 3. Fungsi Update Stok (Ambil / Tambah)
  Future<void> _updateStok(
    String id,
    int stokLama,
    int jumlahUbah,
    bool isPengurangan,
  ) async {
    final int stokBaru = isPengurangan
        ? (stokLama - jumlahUbah)
        : (stokLama + jumlahUbah);

    if (stokBaru < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Stok tidak cukup!")));
      return;
    }

    try {
      // Update Database
      await _supabase.from('barang').update({'stok': stokBaru}).eq('id', id);

      // Refresh Data UI
      await _fetchBarang();
      if (mounted) Navigator.pop(context); // Tutup Dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPengurangan
                ? "Barang berhasil diambil"
                : "Stok berhasil ditambah",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal update: $e")));
    }
  }

  // 4. Dialog Pop-up Menu
  void _showStokDialog(Map<String, dynamic> item) {
    final stokController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            item['nama_barang'],
            style: TextStyle(
              color: Colors.purple[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Sisa Stok Saat Ini: ${item['stok']} ${item['satuan'] ?? 'Unit'}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: stokController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Jumlah",
                  border: OutlineInputBorder(),
                  hintText: "0",
                ),
              ),
            ],
          ),
          actions: [
            // TOMBOL TAMBAH (RESTOCK)
            TextButton.icon(
              onPressed: () {
                final int? jml = int.tryParse(stokController.text);
                if (jml != null && jml > 0)
                  _updateStok(item['id'].toString(), item['stok'], jml, false);
              },
              icon: const Icon(Icons.add_circle, color: Colors.green),
              label: const Text(
                "Restock (+)",
                style: TextStyle(color: Colors.green),
              ),
            ),

            // TOMBOL AMBIL (BARANG KELUAR)
            ElevatedButton.icon(
              onPressed: () {
                final int? jml = int.tryParse(stokController.text);
                if (jml != null && jml > 0)
                  _updateStok(item['id'].toString(), item['stok'], jml, true);
              },
              icon: const Icon(Icons.remove_circle),
              label: const Text("Ambil (-)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50], // Tema Ungu
      appBar: AppBar(
        title: const Text("Stok Gudang"),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[800],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterBarang,
              decoration: InputDecoration(
                hintText: "Cari Obat / Barang...",
                prefixIcon: const Icon(Icons.search, color: Colors.purple),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 20,
                ),
              ),
            ),
          ),

          // LIST BARANG
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredList.isEmpty
                ? const Center(child: Text("Barang tidak ditemukan"))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredList[index];
                      final stok = item['stok'] ?? 0;
                      final isCritical = stok < 10; // Merah kalau stok tipis

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isCritical
                                ? Colors.red[100]
                                : Colors.green[100],
                            child: Icon(
                              isCritical ? Icons.warning : Icons.inventory_2,
                              color: isCritical ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(
                            item['nama_barang'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text("${item['kategori'] ?? 'Umum'}"),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "$stok ${item['satuan'] ?? ''}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isCritical
                                      ? Colors.red
                                      : Colors.purple[900],
                                ),
                              ),
                              if (isCritical)
                                const Text(
                                  "Stok Menipis!",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                          onTap: () => _showStokDialog(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      // TOMBOL TAMBAH BARANG BARU (Cuma buat Admin Gudang biasanya)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Fitur Tambah Item Baru belum dibuat"),
            ),
          );
        },
        backgroundColor: Colors.purple[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

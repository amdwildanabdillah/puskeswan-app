import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataPeternakScreen extends StatefulWidget {
  final String role; // Menerima peran user (Admin/Dokter)
  const DataPeternakScreen({super.key, required this.role});

  @override
  State<DataPeternakScreen> createState() => _DataPeternakScreenState();
}

class _DataPeternakScreenState extends State<DataPeternakScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController(); // Buat kolom pencarian
  String _keyword = ""; // Kata kunci pencarian

  // --- FUNGSI TAMBAH DATA ---
  Future<void> _tambahPeternak(String nama, String alamat, String noHp) async {
    if (nama.isEmpty) return;
    try {
      await _supabase.from('peternak').insert({
        'nama': nama,
        'alamat': alamat,
        'no_hp': noHp,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Berhasil disimpan!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- POPUP FORM ---
  void _showForm() {
    final namaCtrl = TextEditingController();
    final alamatCtrl = TextEditingController();
    final hpCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah Data Peternak"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: namaCtrl,
              decoration: const InputDecoration(labelText: "Nama Lengkap"),
            ),
            TextField(
              controller: alamatCtrl,
              decoration: const InputDecoration(labelText: "Alamat / Desa"),
            ),
            TextField(
              controller: hpCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Nomor HP"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              if (namaCtrl.text.isNotEmpty) {
                _tambahPeternak(namaCtrl.text, alamatCtrl.text, hpCtrl.text);
                Navigator.pop(context);
              }
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
      appBar: AppBar(
        title: const Text("Database Peternak"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- 1. KOLOM PENCARIAN ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green[50],
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Cari Nama atau Alamat...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _keyword = "");
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _keyword = value.toLowerCase();
                });
              },
            ),
          ),

          // --- 2. DAFTAR PETERNAK ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('peternak')
                  .stream(primaryKey: ['id'])
                  .order('nama'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!;

                // Filter data sesuai ketikan pencarian
                final filteredData = data.where((item) {
                  final nama = item['nama'].toString().toLowerCase();
                  final alamat = item['alamat'].toString().toLowerCase();
                  return nama.contains(_keyword) || alamat.contains(_keyword);
                }).toList();

                if (filteredData.isEmpty) {
                  return const Center(child: Text("Data tidak ditemukan."));
                }

                return ListView.builder(
                  itemCount: filteredData.length,
                  itemBuilder: (context, index) {
                    final item = filteredData[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: Text(
                            item['nama'][0].toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        title: Text(
                          item['nama'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("${item['alamat']} • ${item['no_hp']}"),

                        // --- LOGIKA HAPUS: CUMA ADMIN ---
                        trailing: widget.role == 'Admin Gudang'
                            ? IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.grey,
                                ),
                                onPressed: () async {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Hapus Data?"),
                                      content: const Text(
                                        "Data ini akan hilang permanen.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Batal"),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await _supabase
                                                .from('peternak')
                                                .delete()
                                                .eq('id', item['id']);
                                          },
                                          child: const Text(
                                            "Hapus",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : null, // Dokter ga punya tombol hapus
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // --- TOMBOL TAMBAH: SEMUA BISA AKSES (DOKTER & ADMIN) ---
      floatingActionButton: FloatingActionButton(
        onPressed: _showForm,
        backgroundColor: Colors.green,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}

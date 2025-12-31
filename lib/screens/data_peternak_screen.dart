import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DataPeternakScreen extends StatefulWidget {
  final String role;
  const DataPeternakScreen({super.key, required this.role});

  @override
  State<DataPeternakScreen> createState() => _DataPeternakScreenState();
}

class _DataPeternakScreenState extends State<DataPeternakScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _peternakList = [];
  List<Map<String, dynamic>> _filteredList = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPeternak();
  }

  // 1. AMBIL DATA
  Future<void> _fetchPeternak() async {
    try {
      final data = await _supabase
          .from('peternak')
          .select()
          .order('nama', ascending: true); // Sesuaikan kolom 'nama'

      setState(() {
        _peternakList = List<Map<String, dynamic>>.from(data);
        _filteredList = _peternakList;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 2. CARI DATA
  void _filterPeternak(String query) {
    setState(() {
      _filteredList = _peternakList.where((item) {
        final nama = item['nama'].toString().toLowerCase();
        final alamat = item['alamat'].toString().toLowerCase();
        return nama.contains(query.toLowerCase()) ||
            alamat.contains(query.toLowerCase());
      }).toList();
    });
  }

  // 3. TAMBAH / EDIT DATA
  void _showFormDialog({Map<String, dynamic>? item}) {
    final namaController = TextEditingController(text: item?['nama'] ?? '');
    final alamatController = TextEditingController(text: item?['alamat'] ?? '');
    final hpController = TextEditingController(text: item?['no_hp'] ?? '');
    final isEdit = item != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEdit ? "Edit Peternak" : "Tambah Peternak",
          style: TextStyle(color: Colors.purple[800]),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: namaController,
              decoration: const InputDecoration(labelText: "Nama Lengkap"),
            ),
            TextField(
              controller: alamatController,
              decoration: const InputDecoration(labelText: "Alamat / Desa"),
            ),
            TextField(
              controller: hpController,
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
            onPressed: () async {
              if (namaController.text.isEmpty) return;
              Navigator.pop(context); // Tutup dialog dulu

              try {
                if (isEdit) {
                  // UPDATE
                  await _supabase
                      .from('peternak')
                      .update({
                        'nama': namaController.text,
                        'alamat': alamatController.text,
                        'no_hp': hpController.text,
                      })
                      .eq('id', item['id']);
                } else {
                  // INSERT BARU
                  await _supabase.from('peternak').insert({
                    'nama': namaController.text,
                    'alamat': alamatController.text,
                    'no_hp': hpController.text,
                  });
                }
                _fetchPeternak(); // Refresh list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Data berhasil disimpan!"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Gagal simpan: $e")));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[800],
              foregroundColor: Colors.white,
            ),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  // 4. HAPUS DATA
  Future<void> _deletePeternak(int id) async {
    try {
      await _supabase.from('peternak').delete().eq('id', id);
      _fetchPeternak();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Data dihapus")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal menghapus")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        title: const Text("Data Peternak"),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterPeternak,
              decoration: InputDecoration(
                hintText: "Cari Nama atau Alamat...",
                prefixIcon: const Icon(Icons.search, color: Colors.purple),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // LIST DATA
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final data = _filteredList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple[100],
                            child: Text(
                              data['nama'][0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.purple[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            data['nama'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${data['alamat']} • ${data['no_hp'] ?? '-'}",
                          ),
                          trailing: PopupMenuButton(
                            onSelected: (value) {
                              if (value == 'edit') _showFormDialog(item: data);
                              if (value == 'delete')
                                _deletePeternak(data['id']);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text("Edit"),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: Colors.purple[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GudangScreen extends StatefulWidget {
  final String role; // Menerima peran user
  const GudangScreen({super.key, required this.role});

  @override
  State<GudangScreen> createState() => _GudangScreenState();
}

class _GudangScreenState extends State<GudangScreen> {
  final _supabase = Supabase.instance.client;

  Future<void> _tambahBarang(String nama, String stok, String jenis) async {
    if (nama.isEmpty || stok.isEmpty) return;
    try {
      await _supabase.from('barang').insert({
        'nama_barang': nama,
        'stok': int.parse(stok),
        'jenis': jenis,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showFormTambah() {
    final namaCtrl = TextEditingController();
    final stokCtrl = TextEditingController();
    String jenis = 'Obat';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Tambah Barang"),
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
              DropdownButton<String>(
                value: jenis,
                isExpanded: true,
                items: ['Obat', 'Pakan', 'Alat']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setDialogState(() => jenis = val!),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () =>
                  _tambahBarang(namaCtrl.text, stokCtrl.text, jenis),
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stok Gudang"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('barang')
            .stream(primaryKey: ['id'])
            .order('nama_barang'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.isEmpty) return const Center(child: Text("Gudang kosong."));

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item['jenis'] == 'Obat'
                        ? Colors.red[100]
                        : Colors.amber[100],
                    child: Icon(
                      item['jenis'] == 'Obat' ? Icons.medication : Icons.grass,
                      color: Colors.black54,
                    ),
                  ),
                  title: Text(
                    item['nama_barang'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(item['jenis']),
                  trailing: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${item['stok']} Unit",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      // LOGIKA KUNCI: Kalau bukan Admin, tombol (+) hilang
      floatingActionButton: widget.role == 'Admin Gudang'
          ? FloatingActionButton(
              onPressed: _showFormTambah,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

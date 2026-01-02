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
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _barangList = [];
  List<Map<String, dynamic>> _filteredList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBarang();
  }

  Future<void> _fetchBarang() async {
    try {
      final data = await _supabase
          .from('barang')
          .select()
          .order('nama_barang', ascending: true);

      if (mounted) {
        setState(() {
          _barangList = List<Map<String, dynamic>>.from(data);
          _filteredList = _barangList;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Silent error
    }
  }

  void _filterBarang(String query) {
    setState(() {
      _filteredList = _barangList.where((item) {
        final nama = item['nama_barang'].toString().toLowerCase();
        return nama.contains(query.toLowerCase());
      }).toList();
    });
  }

  // --- LOGIKA UPDATE STOK (BARU) ---
  Future<void> _updateStok(Map<String, dynamic> item, String tipe) async {
    // Tipe: 'masuk' atau 'keluar'
    final qtyController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tipe == 'masuk' ? "Barang Masuk (+)" : "Ambil Barang (-)",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: tipe == 'masuk' ? Colors.green : Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Stok saat ini: ${item['stok']} ${item['satuan']}",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Jumlah",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixText: item['satuan'],
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
              int qty = int.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) return;

              int stokBaru = item['stok'];
              if (tipe == 'masuk') {
                stokBaru += qty;
              } else {
                if (qty > stokBaru) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Stok tidak cukup!")),
                  );
                  return;
                }
                stokBaru -= qty;
              }

              // Update ke Database
              await _supabase
                  .from('barang')
                  .update({'stok': stokBaru})
                  .eq('id', item['id']);

              if (mounted) {
                Navigator.pop(context);
                _fetchBarang(); // Refresh UI
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tipe == 'masuk'
                          ? "Stok bertambah! 📈"
                          : "Barang berhasil diambil! 📉",
                    ),
                    backgroundColor: tipe == 'masuk'
                        ? Colors.green
                        : Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tipe == 'masuk' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(tipe == 'masuk' ? "Tambah" : "Ambil"),
          ),
        ],
      ),
    );
  }

  // Dialog Edit Data Barang (Full)
  Future<void> _showFormDialog({Map<String, dynamic>? item}) async {
    final namaController = TextEditingController(
      text: item?['nama_barang'] ?? '',
    );
    final stokController = TextEditingController(
      text: item?['stok']?.toString() ?? '0',
    );
    final satuanController = TextEditingController(
      text: item?['satuan'] ?? 'Pcs',
    );
    final kategoriController = TextEditingController(
      text: item?['kategori'] ?? 'Obat',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          item == null ? "Tambah Barang Baru" : "Edit Data Barang",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(namaController, "Nama Barang"),
              const SizedBox(height: 10),
              // Kalau edit, stok dikunci biar ga dipake buat transaksi (pake tombol + - aja)
              _buildTextField(
                stokController,
                "Stok Awal",
                isNumber: true,
                isEnabled: item == null,
              ),
              const SizedBox(height: 10),
              _buildTextField(satuanController, "Satuan (Botol/Pcs/Box)"),
              const SizedBox(height: 10),
              _buildTextField(
                kategoriController,
                "Kategori (Obat/Alat/Vaksin)",
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
              final data = {
                'nama_barang': namaController.text,
                'stok': int.tryParse(stokController.text) ?? 0,
                'satuan': satuanController.text,
                'kategori': kategoriController.text,
              };

              if (item == null) {
                await _supabase.from('barang').insert(data);
              } else {
                // Update detail (tanpa stok kalau mode edit)
                final updateData = Map<String, dynamic>.from(data);
                if (item != null)
                  updateData.remove(
                    'stok',
                  ); // Stok lewat fitur Masuk/Keluar aja biar aman

                await _supabase
                    .from('barang')
                    .update(updateData)
                    .eq('id', item['id']);
              }
              if (mounted) {
                Navigator.pop(context);
                _fetchBarang();
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

  Future<void> _deleteBarang(int id) async {
    await _supabase.from('barang').delete().eq('id', id);
    _fetchBarang();
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
        centerTitle: true,
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
                hintText: "Cari obat, vaksin, atau alat...",
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Colors.purple),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredList.isEmpty
                ? Center(
                    child: Text(
                      "Barang tidak ditemukan",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredList[index];
                      final stok = item['stok'] ?? 0;
                      final isLowStock = stok < 10;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
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
                        child: Row(
                          children: [
                            // ICON BARANG
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isLowStock
                                    ? Colors.red[50]
                                    : Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: isLowStock ? Colors.red : Colors.green,
                              ),
                            ),
                            const SizedBox(width: 16),

                            // NAMA & KATEGORI
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['nama_barang'],
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "${item['kategori']} • ${item['satuan']}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // --- BAGIAN STOK & TOMBOL AKSI (BARU) ---
                            Row(
                              children: [
                                // Tombol AMBIL (-)
                                InkWell(
                                  onTap: () => _updateStok(item, 'keluar'),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),

                                // Angka Stok
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    "$stok",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isLowStock
                                          ? Colors.red
                                          : Colors.black87,
                                    ),
                                  ),
                                ),

                                // Tombol MASUK (+)
                                InkWell(
                                  onTap: () => _updateStok(item, 'masuk'),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // MENU Edit/Hapus
                            PopupMenuButton(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.grey,
                                size: 20,
                              ),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 16),
                                      SizedBox(width: 8),
                                      Text("Edit Info"),
                                    ],
                                  ),
                                ),
                                if (widget.role ==
                                    'Admin Gudang') // Cuma admin yang boleh hapus
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
                              onSelected: (value) {
                                if (value == 'edit')
                                  _showFormDialog(item: item);
                                if (value == 'delete')
                                  _deleteBarang(item['id']);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Barang Baru",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    bool isEnabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: isEnabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: !isEnabled,
        fillColor: !isEnabled ? Colors.grey[200] : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

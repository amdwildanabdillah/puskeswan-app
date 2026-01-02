import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailPeternakScreen extends StatefulWidget {
  final Map<String, dynamic> peternak; // Data peternak yang diklik

  const DetailPeternakScreen({super.key, required this.peternak});

  @override
  State<DetailPeternakScreen> createState() => _DetailPeternakScreenState();
}

class _DetailPeternakScreenState extends State<DetailPeternakScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _listHewan = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHewan();
  }

  // Ambil Data Hewan milik Peternak ini
  Future<void> _fetchHewan() async {
    try {
      final data = await _supabase
          .from('hewan')
          .select()
          .eq('peternak_id', widget.peternak['id'])
          .order('created_at', ascending: false);

      setState(() {
        _listHewan = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Fungsi Tambah Hewan Baru
  Future<void> _tambahHewanDialog() async {
    final jenisController = TextEditingController(text: 'Sapi');
    final kodeController = TextEditingController(); // Misal: Anting A001
    final ciriController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Tambah Hewan Ternak",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: jenisController,
              decoration: const InputDecoration(
                labelText: "Jenis (Sapi/Kambing)",
              ),
            ),
            TextField(
              controller: kodeController,
              decoration: const InputDecoration(
                labelText: "Kode Anting / Nama",
              ),
            ),
            TextField(
              controller: ciriController,
              decoration: const InputDecoration(labelText: "Ciri-ciri / Warna"),
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
              if (kodeController.text.isEmpty) return;
              await _supabase.from('hewan').insert({
                'peternak_id': widget.peternak['id'],
                'jenis': jenisController.text,
                'kode_anting': kodeController.text,
                'ciri_ciri': ciriController.text,
              });
              Navigator.pop(context);
              _fetchHewan(); // Refresh list
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Uizard Style
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Detail Peternak",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. KARTU PROFIL PETERNAK (Desain Baru)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5), // Ungu Muda Soft
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.purple,
                    child: Text(
                      widget.peternak['nama'][0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.peternak['nama'],
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.peternak['alamat'] ?? 'Alamat tidak ada',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            widget.peternak['no_hp'] ?? '-',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // HEADER DAFTAR HEWAN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Daftar Hewan Ternak",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _tambahHewanDialog,
                  icon: const Icon(Icons.add_circle, color: Colors.purple),
                  label: const Text(
                    "Tambah",
                    style: TextStyle(color: Colors.purple),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // LIST HEWAN
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _listHewan.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: Column(
                        children: [
                          Icon(Icons.pets, size: 50, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            "Belum ada data hewan",
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _listHewan.length,
                    itemBuilder: (context, index) {
                      final hewan = _listHewan[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
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
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: hewan['jenis'] == 'Sapi'
                                    ? Colors.orange[50]
                                    : Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons
                                    .pest_control_rodent, // Icon Hewan (sementara)
                                color: hewan['jenis'] == 'Sapi'
                                    ? Colors.orange
                                    : Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hewan['kode_anting'] ?? 'Tanpa ID',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "${hewan['jenis']} • ${hewan['ciri_ciri']}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

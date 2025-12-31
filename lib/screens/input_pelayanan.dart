import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InputPelayananScreen extends StatefulWidget {
  const InputPelayananScreen({super.key});

  @override
  State<InputPelayananScreen> createState() => _InputPelayananScreenState();
}

class _InputPelayananScreenState extends State<InputPelayananScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Controllers
  final _diagnosaController = TextEditingController();
  final _tindakanController = TextEditingController();
  final _biayaController = TextEditingController();
  final _detailHewanController = TextEditingController(); // Baru: Ras/Ciri
  final _jumlahHewanController = TextEditingController(
    text: '1',
  ); // Baru: Jumlah
  final _customHewanController =
      TextEditingController(); // Baru: Buat ketik "Lainnya"

  // State Variables
  List<Map<String, dynamic>> _peternakList = [];
  String? _selectedPeternakId;
  String? _selectedPeternakNama;

  // Pilihan Hewan Standar
  final List<String> _hewanList = [
    'Sapi',
    'Kambing',
    'Domba',
    'Kucing',
    'Anjing',
    'Ayam',
    'Lainnya',
  ];
  String? _selectedHewan;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPeternak();
  }

  // 1. Ambil Data Peternak buat Dropdown
  Future<void> _fetchPeternak() async {
    try {
      final data = await _supabase
          .from('peternak')
          .select('id, nama')
          .order('nama', ascending: true);

      setState(() {
        _peternakList = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data peternak: $e")),
        );
      }
    }
  }

  // 2. Fungsi Simpan ke Database
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPeternakId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih Peternak dulu!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // LOGIKA JENIS HEWAN:
      // Kalau pilih "Lainnya", ambil dari textfield manual. Kalau bukan, ambil dari dropdown.
      String jenisHewanFinal = _selectedHewan == 'Lainnya'
          ? _customHewanController.text.trim()
          : _selectedHewan!;

      // Validasi kalau "Lainnya" tapi kosong
      if (jenisHewanFinal.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Silakan tulis jenis hewannya!")),
        );
        setState(() => _isLoading = false);
        return;
      }

      // KIRIM KE DATABASE
      await _supabase.from('pelayanan').insert({
        'nama_peternak': _selectedPeternakNama, // Simpan nama buat history
        // Idealnya simpan ID juga kalau relasi, tapi sementara nama dulu gapapa
        'jenis_hewan': jenisHewanFinal,
        'detail_hewan': _detailHewanController.text.trim(), // Baru
        'jumlah_hewan': int.tryParse(_jumlahHewanController.text) ?? 1, // Baru
        'diagnosa': _diagnosaController.text.trim(),
        'jenis_layanan': _tindakanController.text.trim(), // Tindakan
        'biaya':
            int.tryParse(
              _biayaController.text.replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0,
        'waktu': DateTime.now().toIso8601String(),
        // Kita simpan email dokter yang login buat laporan kinerja
        'dokter_email': _supabase.auth.currentUser?.email ?? 'admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Laporan Berhasil Disimpan! ✅"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Kembali ke dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50], // Tema Ungu Muda
      appBar: AppBar(
        title: const Text("Input Pelayanan"),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CARD 1: DATA PASIEN ---
              _buildSectionTitle("Data Pasien"),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 1. DROPDOWN PETERNAK
                      DropdownButtonFormField<String>(
                        decoration: _inputDecor("Pilih Peternak", Icons.person),
                        value: _selectedPeternakId,
                        items: _peternakList.map((peternak) {
                          return DropdownMenuItem<String>(
                            value: peternak['id'].toString(),
                            child: Text(peternak['nama']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPeternakId = value;
                            // Cari nama berdasarkan ID
                            final selectedData = _peternakList.firstWhere(
                              (e) => e['id'].toString() == value,
                            );
                            _selectedPeternakNama = selectedData['nama'];
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. DROPDOWN JENIS HEWAN
                      DropdownButtonFormField<String>(
                        decoration: _inputDecor("Jenis Hewan", Icons.pets),
                        value: _selectedHewan,
                        items: _hewanList.map((hewan) {
                          return DropdownMenuItem<String>(
                            value: hewan,
                            child: Text(hewan),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedHewan = value),
                      ),

                      // 3. TEXTFIELD KHUSUS (Muncul cuma kalau pilih "Lainnya")
                      if (_selectedHewan == 'Lainnya')
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: TextFormField(
                            controller: _customHewanController,
                            decoration: _inputDecor(
                              "Tulis Jenis Hewan (Manual)",
                              Icons.edit,
                            ),
                            validator: (val) =>
                                val!.isEmpty ? "Harus diisi" : null,
                          ),
                        ),

                      const SizedBox(height: 16),

                      // 4. ROW: DETAIL & JUMLAH
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _detailHewanController,
                              decoration: _inputDecor(
                                "Detail/Ras (Cth: Limosin)",
                                Icons.info_outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _jumlahHewanController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecor("Jml", Icons.numbers),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- CARD 2: MEDIS & BIAYA ---
              _buildSectionTitle("Data Medis"),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _diagnosaController,
                        decoration: _inputDecor(
                          "Diagnosa",
                          Icons.medical_services,
                        ),
                        validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tindakanController,
                        decoration: _inputDecor(
                          "Tindakan (Cth: Vaksin/IB)",
                          Icons.healing,
                        ),
                        validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _biayaController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecor(
                          "Biaya Pelayanan (Rp)",
                          Icons.monetization_on,
                        ),
                        validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // TOMBOL SIMPAN
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SIMPAN LAPORAN",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Styles
  InputDecoration _inputDecor(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.purple[800]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.purple[800],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Cek Sinyal
import '../services/database_helper.dart'; // Database Lokal

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
  final _detailHewanController = TextEditingController();
  final _jumlahHewanController = TextEditingController(text: '1');
  final _customHewanController = TextEditingController();

  // State Variables
  List<Map<String, dynamic>> _peternakList = [];
  String? _selectedPeternakId;
  String? _selectedPeternakNama;

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

  // 1. Ambil Data Peternak
  Future<void> _fetchPeternak() async {
    // Cek koneksi dulu, kalau offline kita gak bisa load dropdown (Kelemahan V1)
    // Solusi: Pastikan user buka aplikasi pas ada sinyal dulu
    try {
      final data = await _supabase
          .from('peternak')
          .select('id, nama')
          .order('nama', ascending: true);

      if (mounted) {
        setState(() {
          _peternakList = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      // Silent error kalau offline, biar gak ganggu UI
    }
  }

  // 2. LOGIKA UTAMA: HYBRID SAVE (ONLINE/OFFLINE)
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
      // A. Siapkan Data
      String jenisHewanFinal = _selectedHewan == 'Lainnya'
          ? _customHewanController.text.trim()
          : _selectedHewan!;

      if (jenisHewanFinal.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Silakan tulis jenis hewannya!")),
        );
        setState(() => _isLoading = false);
        return;
      }

      int biayaFix =
          int.tryParse(
            _biayaController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      String userEmail = _supabase.auth.currentUser?.email ?? 'admin';
      String waktuSekarang = DateTime.now().toIso8601String();

      // Map Data Standar
      final dataLaporan = {
        'nama_peternak': _selectedPeternakNama,
        'jenis_hewan': jenisHewanFinal,
        'detail_hewan': _detailHewanController.text.trim(),
        'jumlah_hewan': int.tryParse(_jumlahHewanController.text) ?? 1,
        'diagnosa': _diagnosaController.text.trim(),
        'jenis_layanan': _tindakanController.text.trim(),
        'biaya': biayaFix,
        'waktu': waktuSekarang,
        'dokter_email': userEmail,
      };

      // B. CEK KONEKSI INTERNET
      final connectivityResult = await (Connectivity().checkConnectivity());

      // Jika TIDAK ADA koneksi (Mobile, Wifi, Ethernet, dll)
      bool isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        // --- SKENARIO OFFLINE: SIMPAN KE HP ---
        await DatabaseHelper().insertTransaksi(dataLaporan);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("OFFLINE MODE: Data disimpan di HP 💾"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.pop(context); // Balik ke dashboard
        }
      } else {
        // --- SKENARIO ONLINE: KIRIM KE SUPABASE ---
        await _supabase.from('pelayanan').insert(dataLaporan);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("ONLINE: Laporan Terupload! ✅"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Balik ke dashboard
        }
      }
    } catch (e) {
      // Error Handling (Misal sinyal putus di tengah jalan)
      // Opsional: Bisa dipaksa simpan ke lokal kalau error supabase
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal Simpan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
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
                      // Note: Kalau Offline total pas buka app, ini bakal kosong.
                      // Solusi V2 nanti: Cache data peternak juga.
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text(
                              "SIMPAN LAPORAN",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

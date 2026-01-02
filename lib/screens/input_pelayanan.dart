import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/database_helper.dart';

class InputPelayananScreen extends StatefulWidget {
  const InputPelayananScreen({super.key});

  @override
  State<InputPelayananScreen> createState() => _InputPelayananScreenState();
}

class _InputPelayananScreenState extends State<InputPelayananScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  // Controllers
  final _anamnesaController = TextEditingController();
  final _diagnosaController = TextEditingController();
  final _tindakanController = TextEditingController();
  final _biayaController = TextEditingController();

  // State Variables
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isInit = false;

  // --- BAGIAN INI YANG KITA FIX ---
  // Dulu error karena isinya ['Sapi', 'Kambing'] (String)
  // Sekarang kita kosongkan [] biar siap nampung data dari Database (Map)
  List<Map<String, dynamic>> _peternakList = [];
  List<Map<String, dynamic>> _hewanList = [];
  // -------------------------------

  // Selection Variables
  String? _selectedPeternakId;
  String? _selectedPeternakNama;
  String? _selectedHewanId;
  Map<String, dynamic>? _selectedHewanDetail;

  @override
  void initState() {
    super.initState();
    // Inisialisasi Format Tanggal Indo
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) {
        setState(() => _isInit = true);
        _fetchPeternak();
      }
    });
  }

  // 1. AMBIL DATA PETERNAK
  Future<void> _fetchPeternak() async {
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
      // Silent error kalau offline
    }
  }

  // 2. AMBIL DATA HEWAN (Berdasarkan Peternak yg dipilih)
  Future<void> _fetchHewanByPeternak(String peternakId) async {
    try {
      // Reset pilihan hewan saat ganti peternak
      setState(() {
        _hewanList = [];
        _selectedHewanId = null;
        _selectedHewanDetail = null;
      });

      final data = await _supabase
          .from('hewan')
          .select()
          .eq('peternak_id', peternakId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _hewanList = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  // 3. FITUR TAMBAH PETERNAK (Pop-up)
  Future<void> _addPeternakDialog() async {
    final namaCtrl = TextEditingController();
    final alamatCtrl = TextEditingController();
    final hpCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Peternak Baru",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
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
              decoration: const InputDecoration(labelText: "No HP (Opsional)"),
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
              if (namaCtrl.text.isEmpty) return;
              try {
                // Simpan & Ambil data balikan
                final res = await _supabase
                    .from('peternak')
                    .insert({
                      'nama': namaCtrl.text,
                      'alamat': alamatCtrl.text,
                      'no_hp': hpCtrl.text,
                    })
                    .select()
                    .single();

                // Refresh List
                await _fetchPeternak();

                // Otomatis Pilih Peternak Baru
                setState(() {
                  _selectedPeternakId = res['id'].toString();
                  _selectedPeternakNama = res['nama'];
                });
                _fetchHewanByPeternak(res['id'].toString());

                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
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

  // 4. FITUR TAMBAH HEWAN (Pop-up)
  Future<void> _addHewanDialog() async {
    if (_selectedPeternakId == null) return;

    final jenisCtrl = TextEditingController(text: 'Sapi');
    final kodeCtrl = TextEditingController();
    final ciriCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Hewan Baru",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: jenisCtrl,
              decoration: const InputDecoration(
                labelText: "Jenis (Sapi/Kambing)",
              ),
            ),
            TextField(
              controller: kodeCtrl,
              decoration: const InputDecoration(
                labelText: "Kode Anting / Nama",
              ),
            ),
            TextField(
              controller: ciriCtrl,
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
              if (kodeCtrl.text.isEmpty) return;
              try {
                final res = await _supabase
                    .from('hewan')
                    .insert({
                      'peternak_id': _selectedPeternakId,
                      'jenis': jenisCtrl.text,
                      'kode_anting': kodeCtrl.text,
                      'ciri_ciri': ciriCtrl.text,
                    })
                    .select()
                    .single();

                // Refresh List Hewan
                await _fetchHewanByPeternak(_selectedPeternakId!);

                // Otomatis Pilih Hewan Baru
                setState(() {
                  _selectedHewanId = res['id'].toString();
                  _selectedHewanDetail = res;
                });

                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
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

  // DATE PICKER
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.purple),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  // SUBMIT DATA PELAYANAN
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPeternakId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih Peternak dulu!")));
      return;
    }
    if (_selectedHewanId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih Hewan Ternak dulu!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      int biayaFix =
          int.tryParse(
            _biayaController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      String userEmail = _supabase.auth.currentUser?.email ?? 'admin';

      // Format info hewan biar jelas di riwayat
      String detailHewanFix =
          "${_selectedHewanDetail?['kode_anting']} - ${_selectedHewanDetail?['ciri_ciri']}";

      final dataLaporan = {
        'nama_peternak': _selectedPeternakNama,
        'jenis_hewan': _selectedHewanDetail?['jenis'] ?? 'Umum',
        'detail_hewan': detailHewanFix,
        'jumlah_hewan': 1, // Default 1 ekor per transaksi
        'anamnesa': _anamnesaController.text.trim(),
        'diagnosa': _diagnosaController.text.trim(),
        'jenis_layanan': _tindakanController.text.trim(),
        'biaya': biayaFix,
        'waktu': _selectedDate.toIso8601String(),
        'dokter_email': userEmail,
      };

      // Cek Sinyal (Online/Offline)
      final connectivityResult = await (Connectivity().checkConnectivity());
      bool isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        await DatabaseHelper().insertTransaksi(dataLaporan);
        if (mounted)
          _showSuccessDialog(
            "OFFLINE MODE",
            "Data tersimpan di HP. Upload saat online nanti ya!",
            Colors.orange,
          );
      } else {
        await _supabase.from('pelayanan').insert(dataLaporan);
        if (mounted)
          _showSuccessDialog(
            "BERHASIL",
            "Laporan pelayanan tersimpan!",
            Colors.green,
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.wifi_off,
              size: 50,
              color: color,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Balik Dashboard
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: const Text("OK, Mengerti"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading awal buat siapin Kamus Tanggal
    if (!_isInit)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Input Pelayanan",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0. DATE PICKER
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.purple),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Tanggal Pelayanan",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.purple[900],
                            ),
                          ),
                          Text(
                            DateFormat(
                              'EEEE, d MMMM yyyy',
                              'id_ID',
                            ).format(_selectedDate),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.edit, size: 16, color: Colors.purple),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 1. DATA PASIEN
              _buildHeader("Data Pasien", Icons.pets),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: _boxDecoration(),
                child: Column(
                  children: [
                    // PILIH PETERNAK
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: _inputDecor("Pilih Peternak"),
                            value: _selectedPeternakId,
                            isExpanded: true,
                            items: _peternakList.map((peternak) {
                              return DropdownMenuItem<String>(
                                value: peternak['id'].toString(),
                                child: Text(
                                  peternak['nama'],
                                  style: GoogleFonts.poppins(),
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                              // Ambil Hewan milik Peternak ini
                              _fetchHewanByPeternak(value!);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // TOMBOL ADD PETERNAK
                        InkWell(
                          onTap: _addPeternakDialog,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // PILIH HEWAN
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: _inputDecor("Pilih Hewan Ternak"),
                            value: _selectedHewanId,
                            isExpanded: true,
                            hint: Text(
                              _selectedPeternakId == null
                                  ? "Pilih peternak dulu"
                                  : "Pilih sapi/kambing...",
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            // Data Hewan diambil dari Database, bukan List String manual lagi
                            items: _hewanList.map((hewan) {
                              return DropdownMenuItem<String>(
                                value: hewan['id'].toString(),
                                child: Text(
                                  "${hewan['jenis']} - ${hewan['kode_anting']} (${hewan['ciri_ciri']})",
                                  style: GoogleFonts.poppins(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: _selectedPeternakId == null
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedHewanId = value;
                                      _selectedHewanDetail = _hewanList
                                          .firstWhere(
                                            (e) => e['id'].toString() == value,
                                          );
                                    });
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // TOMBOL ADD HEWAN
                        InkWell(
                          onTap: _selectedPeternakId == null
                              ? null
                              : _addHewanDialog,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedPeternakId == null
                                  ? Colors.grey[200]
                                  : Colors.purple[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.add_circle,
                              color: _selectedPeternakId == null
                                  ? Colors.grey
                                  : Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 2. MEDIS & BIAYA
              _buildHeader("Medis & Biaya", Icons.medical_services),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: _boxDecoration(),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _anamnesaController,
                      maxLines: 2,
                      decoration: _inputDecor("Anamnesa / Keluhan"),
                      validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _diagnosaController,
                      decoration: _inputDecor("Diagnosa Penyakit"),
                      validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tindakanController,
                      decoration: _inputDecor("Tindakan / Obat"),
                      validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _biayaController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecor("Biaya Pelayanan (Rp)"),
                      validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // TOMBOL SIMPAN
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_rounded),
                            const SizedBox(width: 8),
                            Text(
                              "SIMPAN LAPORAN",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Styles
  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey[100]!),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.purple, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

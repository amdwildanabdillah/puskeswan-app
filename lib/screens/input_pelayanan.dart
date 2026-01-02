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

  // --- STATE VARIABLES ---
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isInit = false;

  // DATA LISTS
  List<Map<String, dynamic>> _peternakList = [];
  List<Map<String, dynamic>> _hewanList = [];
  List<Map<String, dynamic>> _obatList = [];
  List<String> _diagnosaList = [
    'Demam Three Day',
    'PMK',
    'LSD',
    'Kembung',
    'Cacingan',
  ];
  List<String> _bangsaList = ['Limosin', 'Simental', 'PO', 'Brahman', 'Jawa'];

  // SELECTION
  String? _selectedPeternakId;
  String? _selectedPeternakNama;
  String? _selectedHewanId;
  Map<String, dynamic>? _selectedHewanDetail;

  // LOGIC UI
  String _kategoriLayanan = 'Pengobatan';
  final List<String> _layananOptions = [
    'Pengobatan',
    'IB (Inseminasi)',
    'PKB (Cek Hamil)',
    'Vaksinasi',
  ];

  // CONTROLLERS
  final _anamnesaController = TextEditingController();
  final _diagnosaController = TextEditingController();
  final _tindakanController = TextEditingController();
  final _biayaController = TextEditingController();
  final _strawController = TextEditingController();

  // OBAT CONTROLLERS (Max 5)
  final List<String?> _selectedObatIds = [null, null, null, null, null];
  final List<String?> _selectedObatNames = [null, null, null, null, null];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) {
        setState(() => _isInit = true);
        _fetchInitialData();
      }
    });
  }

  Future<void> _fetchInitialData() async {
    try {
      final dataPeternak = await _supabase
          .from('peternak')
          .select('id, nama')
          .order('nama');
      final dataObat = await _supabase
          .from('barang')
          .select('id, nama_barang, stok')
          .gt('stok', 0)
          .order('nama_barang');

      try {
        final dataDiagnosa = await _supabase
            .from('master_diagnosa')
            .select('nama_penyakit');
        final dataBangsa = await _supabase
            .from('master_bangsa')
            .select('nama_bangsa');
        if (mounted) {
          setState(() {
            _diagnosaList = List<String>.from(
              dataDiagnosa.map((e) => e['nama_penyakit']),
            );
            _bangsaList = List<String>.from(
              dataBangsa.map((e) => e['nama_bangsa']),
            );
          });
        }
      } catch (e) {} // Silent fail

      if (mounted) {
        setState(() {
          _peternakList = List<Map<String, dynamic>>.from(dataPeternak);
          _obatList = List<Map<String, dynamic>>.from(dataObat);
        });
      }
    } catch (e) {}
  }

  Future<void> _fetchHewanByPeternak(String peternakId) async {
    try {
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
      if (mounted)
        setState(() => _hewanList = List<Map<String, dynamic>>.from(data));
    } catch (e) {}
  }

  // --- POPUP ADD PETERNAK ---
  Future<void> _addPeternakDialog() async {
    final namaCtrl = TextEditingController();
    final desaCtrl = TextEditingController();
    final rtCtrl = TextEditingController();
    final hpCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Peternak Baru",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                decoration: _inputDecor("Nama Lengkap"),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: desaCtrl,
                      decoration: _inputDecor("Desa"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: rtCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecor("RT"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hpCtrl,
                keyboardType: TextInputType.phone,
                decoration: _inputDecor("No HP (Opsional)"),
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
              if (namaCtrl.text.isEmpty) return;
              try {
                final res = await _supabase
                    .from('peternak')
                    .insert({
                      'nama': namaCtrl.text,
                      'alamat': "${desaCtrl.text}, RT ${rtCtrl.text}",
                      'desa': desaCtrl.text,
                      'rt': rtCtrl.text,
                      'no_hp': hpCtrl.text,
                    })
                    .select()
                    .single();

                await _fetchInitialData();
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

  // --- POPUP ADD HEWAN (REVISI LENGKAP) ---
  Future<void> _addHewanDialog() async {
    if (_selectedPeternakId == null) return;

    String? jenis;
    String? bangsa;
    final kodeCtrl = TextEditingController();
    final ciriCtrl = TextEditingController();
    final newJenisCtrl = TextEditingController();
    final newBangsaCtrl = TextEditingController();

    List<String> localJenisList = ['Sapi', 'Kambing', 'Domba'];
    List<String> localBangsaList = List.from(_bangsaList);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(
              "Hewan Baru",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: jenis,
                    decoration: _inputDecor("Jenis Hewan"),
                    hint: const Text("Pilih Jenis"),
                    items: [
                      ...localJenisList.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e)),
                      ),
                      const DropdownMenuItem(
                        value: 'ADD_NEW',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: Colors.purple),
                            Text(
                              " Lainnya...",
                              style: TextStyle(color: Colors.purple),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == 'ADD_NEW') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Jenis Hewan Baru"),
                            content: TextField(
                              controller: newJenisCtrl,
                              decoration: _inputDecor("Nama Jenis"),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  if (newJenisCtrl.text.isNotEmpty) {
                                    setStateSB(() {
                                      localJenisList.add(newJenisCtrl.text);
                                      jenis = newJenisCtrl.text;
                                    });
                                    Navigator.pop(ctx);
                                  }
                                },
                                child: const Text("Tambah"),
                              ),
                            ],
                          ),
                        );
                      } else {
                        setStateSB(() => jenis = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: bangsa,
                    decoration: _inputDecor("Bangsa / Ras"),
                    hint: const Text("Pilih Ras (Limosin, dll)"),
                    items: [
                      ...localBangsaList.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e)),
                      ),
                      const DropdownMenuItem(
                        value: 'ADD_NEW',
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 16, color: Colors.purple),
                            Text(
                              " Tambah Ras...",
                              style: TextStyle(color: Colors.purple),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == 'ADD_NEW') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Tambah Ras Baru"),
                            content: TextField(
                              controller: newBangsaCtrl,
                              decoration: _inputDecor("Nama Ras"),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () {
                                  if (newBangsaCtrl.text.isNotEmpty) {
                                    try {
                                      _supabase.from('master_bangsa').insert({
                                        'nama_bangsa': newBangsaCtrl.text,
                                      });
                                    } catch (e) {}
                                    setStateSB(() {
                                      localBangsaList.add(newBangsaCtrl.text);
                                      bangsa = newBangsaCtrl.text;
                                    });
                                    Navigator.pop(ctx);
                                  }
                                },
                                child: const Text("Tambah"),
                              ),
                            ],
                          ),
                        );
                      } else {
                        setStateSB(() => bangsa = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: kodeCtrl,
                    decoration: _inputDecor("Kode Anting / Nama"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ciriCtrl,
                    decoration: _inputDecor("Ciri-ciri / Warna (Opsional)"),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          color: Colors.grey,
                          size: 30,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Upload Foto (Opsional)",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
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
                  if (kodeCtrl.text.isEmpty || jenis == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Jenis & Identitas Wajib Diisi!"),
                      ),
                    );
                    return;
                  }
                  try {
                    final res = await _supabase
                        .from('hewan')
                        .insert({
                          'peternak_id': _selectedPeternakId,
                          'jenis': jenis,
                          'bangsa': bangsa,
                          'kode_anting': kodeCtrl.text,
                          'ciri_ciri': ciriCtrl.text,
                        })
                        .select()
                        .single();

                    await _fetchHewanByPeternak(_selectedPeternakId!);
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
          );
        },
      ),
    );
  }

  // --- SUBMIT UTAMA ---
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPeternakId == null || _selectedHewanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data Pasien belum lengkap!")),
      );
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

      String detailHewanFix =
          "${_selectedHewanDetail?['kode_anting']} - ${_selectedHewanDetail?['bangsa'] ?? ''}";

      final dataLaporan = {
        'nama_peternak': _selectedPeternakNama,
        'jenis_hewan': _selectedHewanDetail?['jenis'] ?? 'Umum',
        'detail_hewan': detailHewanFix,
        'jumlah_hewan': 1,
        'anamnesa': _anamnesaController.text.trim(),
        'kategori_layanan': _kategoriLayanan,
        'diagnosa': _kategoriLayanan == 'Pengobatan'
            ? _diagnosaController.text.trim()
            : '-',
        'jenis_layanan': _tindakanController.text.trim(),
        'kode_straw': _kategoriLayanan == 'IB (Inseminasi)'
            ? _strawController.text.trim()
            : null,
        'obat_1': _selectedObatNames[0],
        'obat_2': _selectedObatNames[1],
        'obat_3': _selectedObatNames[2],
        'obat_4': _selectedObatNames[3],
        'obat_5': _selectedObatNames[4],
        'biaya': biayaFix,
        'waktu': _selectedDate.toIso8601String(),
        'dokter_email': userEmail,
      };

      final connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        await DatabaseHelper().insertTransaksi(dataLaporan);
        if (mounted)
          _showSuccessDialog(
            "OFFLINE MODE",
            "Data tersimpan di HP.",
            Colors.orange,
          );
      } else {
        await _supabase.from('pelayanan').insert(dataLaporan);
        if (mounted)
          _showSuccessDialog("BERHASIL", "Laporan tersimpan!", Colors.green);
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
            Icon(Icons.check_circle, size: 50, color: color),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Input Pelayanan",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      // WRAP PAKE SAFEAREA BIAR GA KEPOTONG STATUS BAR/NAV BAR BROWSER
      body: SafeArea(
        child: SingleChildScrollView(
          // TAMBAH PADDING BAWAH YANG BANYAK BIAR BISA DI SCROLL SAMPAI MENTOK
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.purple),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat(
                            'EEEE, d MMMM yyyy',
                            'id_ID',
                          ).format(_selectedDate),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildSectionTitle("Data Pasien", Icons.pets),
                _buildCardContainer(
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: _inputDecor("Pilih Peternak"),
                              value: _selectedPeternakId,
                              isExpanded: true,
                              items: _peternakList
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p['id'].toString(),
                                      child: Text(p['nama']),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedPeternakId = val;
                                  _selectedPeternakNama = _peternakList
                                      .firstWhere(
                                        (e) => e['id'].toString() == val,
                                      )['nama'];
                                });
                                _fetchHewanByPeternak(val!);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildAddButton(_addPeternakDialog),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: _inputDecor("Pilih Hewan"),
                              value: _selectedHewanId,
                              hint: const Text("Pilih Hewan..."),
                              isExpanded: true,
                              items: _hewanList
                                  .map(
                                    (h) => DropdownMenuItem(
                                      value: h['id'].toString(),
                                      child: Text(
                                        "${h['jenis']} - ${h['kode_anting']}",
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _selectedPeternakId == null
                                  ? null
                                  : (val) {
                                      setState(() {
                                        _selectedHewanId = val;
                                        _selectedHewanDetail = _hewanList
                                            .firstWhere(
                                              (e) => e['id'].toString() == val,
                                            );
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildAddButton(
                            _selectedPeternakId == null
                                ? null
                                : _addHewanDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _buildSectionTitle("Jenis Pelayanan", Icons.medical_services),
                _buildCardContainer(
                  DropdownButtonFormField<String>(
                    value: _kategoriLayanan,
                    decoration: _inputDecor("Kategori"),
                    items: _layananOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _kategoriLayanan = val!),
                  ),
                ),

                const SizedBox(height: 24),

                _buildSectionTitle("Detail Medis & Biaya", Icons.assignment),
                _buildCardContainer(
                  Column(
                    children: [
                      TextFormField(
                        controller: _anamnesaController,
                        maxLines: 2,
                        decoration: _inputDecor("Anamnesa (Keluhan)"),
                        validator: (v) => v!.isEmpty ? "Isi dulu" : null,
                      ),
                      const SizedBox(height: 16),

                      if (_kategoriLayanan.contains('IB')) ...[
                        TextFormField(
                          controller: _strawController,
                          decoration: _inputDecor("Kode Straw / Pejantan"),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_kategoriLayanan == 'Pengobatan') ...[
                        DropdownButtonFormField<String>(
                          decoration: _inputDecor("Diagnosa"),
                          value: null,
                          hint: const Text("Pilih / Tambah Diagnosa"),
                          items: [
                            ..._diagnosaList.map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            ),
                            const DropdownMenuItem(
                              value: 'ADD_NEW',
                              child: Text(
                                "+ Tambah Diagnosa Baru",
                                style: TextStyle(color: Colors.purple),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val == 'ADD_NEW') {
                              final diagCtrl = TextEditingController();
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Diagnosa Baru"),
                                  content: TextField(
                                    controller: diagCtrl,
                                    decoration: _inputDecor("Nama Penyakit"),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () {
                                        if (diagCtrl.text.isNotEmpty) {
                                          setState(
                                            () => _diagnosaList.add(
                                              diagCtrl.text,
                                            ),
                                          );
                                          _diagnosaController.text =
                                              diagCtrl.text;
                                          Navigator.pop(ctx);
                                        }
                                      },
                                      child: const Text("Simpan"),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              _diagnosaController.text = val!;
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _tindakanController,
                        decoration: _inputDecor("Tindakan / Penanganan"),
                      ),
                      const SizedBox(height: 16),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Resep Obat:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(5, (index) {
                        if (index == 0 || _selectedObatIds[index - 1] != null) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DropdownButtonFormField<String>(
                              decoration: _inputDecor("Obat ke-${index + 1}"),
                              value: _selectedObatIds[index],
                              isExpanded: true,
                              hint: const Text("Pilih Obat..."),
                              items: _obatList
                                  .map(
                                    (obat) => DropdownMenuItem(
                                      value: obat['id'].toString(),
                                      child: Text(
                                        "${obat['nama_barang']} (Sisa: ${obat['stok']})",
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedObatIds[index] = val;
                                  _selectedObatNames[index] = _obatList
                                      .firstWhere(
                                        (e) => e['id'].toString() == val,
                                      )['nama_barang'];
                                });
                              },
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),

                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _biayaController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecor("Biaya Pelayanan (Rp)"),
                        validator: (v) => v!.isEmpty ? "Isi biaya" : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "SIMPAN LAPORAN",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: child,
    );
  }

  Widget _buildAddButton(VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey[200] : Colors.purple[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.add,
          color: onTap == null ? Colors.grey : Colors.purple,
        ),
      ),
    );
  }
}

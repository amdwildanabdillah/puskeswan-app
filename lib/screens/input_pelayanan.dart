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

  // DATA LISTS DARI DB
  List<Map<String, dynamic>> _peternakList = [];
  List<Map<String, dynamic>> _hewanList = [];
  List<Map<String, dynamic>> _obatList = [];

  // LIST MASTER DATA
  List<String> _diagnosaList = [
    'Demam Three Day',
    'PMK',
    'LSD',
    'Kembung',
    'Cacingan',
  ];
  List<String> _jenisList = ['Sapi', 'Kambing', 'Domba'];
  List<String> _bangsaList = ['Limosin', 'Simental', 'PO', 'Brahman', 'Jawa'];

  // KHUSUS IB
  List<String> _ibJenisList = ['Sapi', 'Kambing', 'Domba'];
  List<String> _ibBangsaList = ['Limosin', 'Simental', 'PO', 'Brahman', 'Jawa'];

  // SELECTION STATE
  String? _selectedPeternakId;
  String? _selectedPeternakNama;
  String? _selectedHewanId;
  Map<String, dynamic>? _selectedHewanDetail;

  // LOGIC UI
  String _kategoriLayanan = 'Pengobatan';
  final List<String> _layananOptions = ['Pengobatan', 'IB', 'PKB'];

  // CONTROLLERS
  final _anamnesaController = TextEditingController();
  final _diagnosaController = TextEditingController();
  final _keteranganController = TextEditingController();
  final _biayaController = TextEditingController();

  // CONTROLLER KHUSUS
  final _strawKodeController = TextEditingController();
  String? _selectedIbJenis;
  String? _selectedIbBangsa;
  String? _pkbStatus;
  final _pkbBulanController = TextEditingController();

  // CONTROLLER DOSIS OBAT
  Map<String, dynamic>? _obatDipilih;
  final _dosisController = TextEditingController();
  final List<Map<String, dynamic>> _listResepFix = [];

  // DATA WILAYAH TRENGGALEK (HARDCODED BIAR CEPAT & OFFLINE READY)
  final Map<String, List<String>> _dataWilayah = {
    'Panggul': [
      'Wonocoyo',
      'Bodag',
      'Kertosono',
      'Panggul',
      'Gayam',
      'Nglebeng',
    ],
    'Munjungan': ['Masaran', 'Munjungan', 'Tawing', 'Bendoroto', 'Bangun'],
    'Pule': ['Pule', 'Pakel', 'Tanggaran', 'Jombok', 'Kuyon', 'Sidomulyo'],
    'Dongko': ['Dongko', 'Ngerdani', 'Siki', 'Pringapus', 'Cakul'],
    'Tugu': ['Nglongsor', 'Prambon', 'Gondang', 'Banaran', 'Winong'],
    'Karangan': ['Karangan', 'Salamrejo', 'Bulurejo', 'Sumberingin'],
    'Kampak': ['Bendoagung', 'Sugihan', 'Timahan', 'Karangrejo'],
    'Watulimo': ['Prigi', 'Tasikmadu', 'Margomulyo', 'Watulimo'],
    'Bendungan': ['Dompyong', 'Surenlor', 'Sumurup', 'Sengon'],
    'Gandusari': ['Gandusari', 'Sukorejo', 'Widoro', 'Wonoanti'],
    'Trenggalek': ['Sumbergedong', 'Surodakan', 'Ngantru', 'Kelutan'],
    'Pogalan': ['Pogalan', 'Ngetal', 'Ngadirejo', 'Bendorejo'],
    'Durenan': ['Durenan', 'Pandean', 'Kendalrejo', 'Semarum'],
    'Suruh': ['Suruh', 'Nglebo', 'Puru', 'Mlinjon'],
  };

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

  // --- FETCH DATA ---
  Future<void> _fetchInitialData() async {
    try {
      final dataPeternak = await _supabase
          .from('peternak')
          .select('id, nama')
          .order('nama');
      final dataObat = await _supabase
          .from('barang')
          .select('id, nama_barang, stok')
          .eq('jenis', 'Obat')
          .gt('stok', 0)
          .order('nama_barang');

      if (mounted) {
        setState(() {
          _peternakList = List<Map<String, dynamic>>.from(dataPeternak);
          _obatList = List<Map<String, dynamic>>.from(dataObat);
        });
      }
    } catch (e) {
      debugPrint("Error Init: $e");
    }
  }

  Future<void> _fetchHewanByPeternak(String peternakId) async {
    try {
      setState(() {
        _hewanList = [];
        _selectedHewanId = null;
        _selectedHewanDetail = null;
      });
      // Filter yang Aktif saja
      final data = await _supabase
          .from('hewan')
          .select()
          .eq('peternak_id', peternakId)
          .eq('status', 'Aktif')
          .order('created_at', ascending: false);
      if (mounted)
        setState(() => _hewanList = List<Map<String, dynamic>>.from(data));
    } catch (e) {}
  }

  // --- LOGIC OBAT ---
  void _tambahObatKeList() {
    if (_obatDipilih == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih obat dulu!")));
      return;
    }
    if (_dosisController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Isi dosis obat (ml)!")));
      return;
    }
    setState(() {
      _listResepFix.add({
        'id': _obatDipilih!['id'],
        'nama': _obatDipilih!['nama_barang'],
        'dosis': _dosisController.text,
      });
      _obatDipilih = null;
      _dosisController.clear();
    });
  }

  // --- POPUP INPUT TEXT HELPER ---
  Future<void> _showTextInputDialog(
    String title,
    Function(String) onSave,
  ) async {
    final txtCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: txtCtrl,
          decoration: _inputDecor("Ketik baru..."),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (txtCtrl.text.isNotEmpty) {
                onSave(txtCtrl.text);
                Navigator.pop(ctx);
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

  // --- DIALOG ADD HEWAN (SINKRON) ---
  Future<void> _addHewanDialog() async {
    if (_selectedPeternakId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih Peternak dulu!")));
      return;
    }

    String? selectedJenis;
    String? selectedBangsa;
    final kodeCtrl = TextEditingController();
    final ciriCtrl = TextEditingController();

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
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedJenis,
                    decoration: _inputDecor("Jenis Hewan"),
                    hint: const Text("Pilih Jenis"),
                    items: [
                      ..._jenisList.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e)),
                      ),
                      const DropdownMenuItem(
                        value: 'NEW',
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
                      if (val == 'NEW') {
                        _showTextInputDialog("Jenis Hewan Baru", (text) {
                          setStateSB(() {
                            _jenisList.add(text);
                            selectedJenis = text;
                          });
                        });
                      } else {
                        setStateSB(() => selectedJenis = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedBangsa,
                    decoration: _inputDecor("Bangsa / Ras"),
                    hint: const Text("Pilih Ras"),
                    items: [
                      ..._bangsaList.map(
                        (e) => DropdownMenuItem(value: e, child: Text(e)),
                      ),
                      const DropdownMenuItem(
                        value: 'NEW',
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
                      if (val == 'NEW') {
                        _showTextInputDialog("Nama Ras Baru", (text) {
                          setStateSB(() {
                            _bangsaList.add(text);
                            selectedBangsa = text;
                          });
                        });
                      } else {
                        setStateSB(() => selectedBangsa = val);
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
                    decoration: _inputDecor("Ciri-ciri"),
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
                  if (kodeCtrl.text.isEmpty || selectedJenis == null) return;
                  try {
                    final res = await _supabase
                        .from('hewan')
                        .insert({
                          'peternak_id': _selectedPeternakId,
                          'jenis': selectedJenis,
                          'bangsa': selectedBangsa,
                          'kode_anting': kodeCtrl.text,
                          'ciri_ciri': ciriCtrl.text,
                          'status': 'Aktif',
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

  // --- DIALOG ADD PETERNAK (REVISI: DROPDOWN WILAYAH) ---
  Future<void> _addPeternakDialog() async {
    final namaCtrl = TextEditingController();
    final rtCtrl = TextEditingController();
    final hpCtrl = TextEditingController();

    // State Lokal Dialog
    String? selectedKecamatan;
    String? selectedDesa;
    List<String> currentDesaList = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // Agar dropdown bisa berubah
        builder: (context, setStateSB) {
          return AlertDialog(
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

                  // DROPDOWN KECAMATAN
                  DropdownButtonFormField<String>(
                    value: selectedKecamatan,
                    decoration: _inputDecor("Kecamatan"),
                    hint: const Text("Pilih Kecamatan"),
                    items: _dataWilayah.keys
                        .map(
                          (kec) =>
                              DropdownMenuItem(value: kec, child: Text(kec)),
                        )
                        .toList(),
                    onChanged: (val) {
                      setStateSB(() {
                        selectedKecamatan = val;
                        selectedDesa = null; // Reset desa saat ganti kecamatan
                        currentDesaList = _dataWilayah[val] ?? [];
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // DROPDOWN DESA (Otomatis muncul sesuai Kecamatan)
                  DropdownButtonFormField<String>(
                    value: selectedDesa,
                    decoration: _inputDecor("Desa / Kelurahan"),
                    hint: const Text("Pilih Desa"),
                    items: currentDesaList
                        .map(
                          (desa) =>
                              DropdownMenuItem(value: desa, child: Text(desa)),
                        )
                        .toList(),
                    onChanged: (val) => setStateSB(() => selectedDesa = val),
                    disabledHint: const Text("Pilih Kecamatan Dulu"),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: rtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecor("RT (Angka)"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hpCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecor("No HP"),
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
                  if (namaCtrl.text.isEmpty ||
                      selectedKecamatan == null ||
                      selectedDesa == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Nama & Alamat wajib diisi!"),
                      ),
                    );
                    return;
                  }
                  try {
                    // Format alamat lengkap
                    String alamatLengkap =
                        "Kec. $selectedKecamatan, Ds. $selectedDesa, RT ${rtCtrl.text}";

                    final res = await _supabase
                        .from('peternak')
                        .insert({
                          'nama': namaCtrl.text,
                          'alamat': alamatLengkap,
                          'kecamatan': selectedKecamatan,
                          'desa': selectedDesa,
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
          );
        },
      ),
    );
  }

  // --- SUBMIT ---
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPeternakId == null || _selectedHewanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Peternak & Hewan wajib dipilih!")),
      );
      return;
    }

    if (_kategoriLayanan == 'Pengobatan' && _listResepFix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Minimal 1 obat untuk Pengobatan!")),
      );
      return;
    }
    if (_kategoriLayanan == 'PKB' && _pkbStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Status Bunting/Tidak wajib dipilih!")),
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
          "${_selectedHewanDetail?['jenis'] ?? ''} - ${_selectedHewanDetail?['kode_anting'] ?? ''}";

      String resepStr = _listResepFix
          .map((e) => "${e['nama']} (${e['dosis']}ml)")
          .join(", ");

      final dataLaporan = {
        'nama_peternak': _selectedPeternakNama,
        'hewan_id': _selectedHewanId,
        'jenis_hewan': _selectedHewanDetail?['jenis'] ?? 'Umum',
        'detail_hewan': detailHewanFix,
        'anamnesa': _anamnesaController.text.trim(),
        'kategori_layanan': _kategoriLayanan,
        'jenis_layanan': _keteranganController.text.trim(),
        'biaya': biayaFix,
        'waktu': _selectedDate.toIso8601String(),
        'dokter_email': userEmail,
        'diagnosa': _kategoriLayanan == 'Pengobatan'
            ? _diagnosaController.text
            : '-',
        'obat_1': _kategoriLayanan == 'Pengobatan' ? resepStr : null,
        'ib_kode_straw': _kategoriLayanan == 'IB'
            ? _strawKodeController.text
            : null,
        'ib_jenis_hewan': _kategoriLayanan == 'IB' ? _selectedIbJenis : null,
        'ib_bangsa': _kategoriLayanan == 'IB' ? _selectedIbBangsa : null,
        'pkb_status': _kategoriLayanan == 'PKB' ? _pkbStatus : null,
        'pkb_usia_bulan': (_kategoriLayanan == 'PKB' && _pkbStatus == 'Bunting')
            ? int.tryParse(_pkbBulanController.text)
            : null,
      };

      final connectivity = await (Connectivity().checkConnectivity());
      if (connectivity.contains(ConnectivityResult.none)) {
        await DatabaseHelper().insertTransaksi(dataLaporan);
        if (mounted)
          _showDialog("OFFLINE", "Data tersimpan di HP.", Colors.orange);
      } else {
        await _supabase.from('pelayanan').insert(dataLaporan);
        if (mounted)
          _showDialog("BERHASIL", "Laporan tersimpan!", Colors.green);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDialog(String title, String msg, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          children: [
            Icon(Icons.check_circle, color: color, size: 50),
            Text(title, style: TextStyle(color: color)),
          ],
        ),
        content: Text(msg, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
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
      body: SafeArea(
        child: SingleChildScrollView(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _layananOptions.map((opt) {
                    bool isActive = _kategoriLayanan == opt;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton(
                          onPressed: () => setState(() {
                            _kategoriLayanan = opt;
                            _listResepFix.clear();
                            _pkbStatus = null;
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive
                                ? Colors.purple
                                : Colors.grey[100],
                            foregroundColor: isActive
                                ? Colors.white
                                : Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            opt,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                _buildSectionTitle(
                  "Detail: $_kategoriLayanan",
                  Icons.assignment,
                ),
                _buildCardContainer(
                  Column(
                    children: [
                      TextFormField(
                        controller: _anamnesaController,
                        decoration: _inputDecor("Anamnesa (Keluhan)"),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      if (_kategoriLayanan == 'Pengobatan')
                        _buildFormPengobatan(),
                      if (_kategoriLayanan == 'IB') _buildFormIB(),
                      if (_kategoriLayanan == 'PKB') _buildFormPKB(),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _keteranganController,
                        decoration: _inputDecor("Keterangan"),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _biayaController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecor("Biaya (Rp)"),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormPengobatan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: _inputDecor("Diagnosa"),
          value: null,
          hint: Text(
            _diagnosaController.text.isEmpty
                ? "Pilih Diagnosa"
                : _diagnosaController.text,
          ),
          items: [
            ..._diagnosaList.map(
              (e) => DropdownMenuItem(value: e, child: Text(e)),
            ),
            const DropdownMenuItem(
              value: 'NEW',
              child: Text(
                "+ Tambah Baru...",
                style: TextStyle(color: Colors.purple),
              ),
            ),
          ],
          onChanged: (val) {
            if (val == 'NEW')
              _showTextInputDialog(
                "Diagnosa Baru",
                (v) => setState(() => _diagnosaController.text = v),
              );
            else
              setState(() => _diagnosaController.text = val!);
          },
        ),
        const SizedBox(height: 16),
        const Text(
          "Resep Obat & Dosis:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<Map<String, dynamic>>(
                isExpanded: true,
                decoration: _inputDecor("Pilih Obat"),
                value: _obatDipilih,
                items: _obatList
                    .map(
                      (o) => DropdownMenuItem(
                        value: o,
                        child: Text(
                          "${o['nama_barang']} (${o['stok']})",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _obatDipilih = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _dosisController,
                keyboardType: TextInputType.number,
                decoration: _inputDecor("ml"),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _tambahObatKeList,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
        if (_listResepFix.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _listResepFix
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "• ${item['nama']}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text("${item['dosis']} ml"),
                          InkWell(
                            onTap: () =>
                                setState(() => _listResepFix.remove(item)),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFormIB() {
    return Column(
      children: [
        TextFormField(
          controller: _strawKodeController,
          decoration: _inputDecor("Kode Straw"),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: _inputDecor("Jenis Hewan"),
          value: _selectedIbJenis,
          items: [
            ..._ibJenisList.map(
              (e) => DropdownMenuItem(value: e, child: Text(e)),
            ),
            const DropdownMenuItem(
              value: 'NEW',
              child: Text(
                "+ Tambah...",
                style: TextStyle(color: Colors.purple),
              ),
            ),
          ],
          onChanged: (v) {
            if (v == 'NEW')
              _showTextInputDialog(
                "Jenis Baru",
                (val) => setState(() => _selectedIbJenis = val),
              );
            else
              setState(() => _selectedIbJenis = v);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: _inputDecor("Bangsa"),
          value: _selectedIbBangsa,
          items: [
            ..._ibBangsaList.map(
              (e) => DropdownMenuItem(value: e, child: Text(e)),
            ),
            const DropdownMenuItem(
              value: 'NEW',
              child: Text(
                "+ Tambah...",
                style: TextStyle(color: Colors.purple),
              ),
            ),
          ],
          onChanged: (v) {
            if (v == 'NEW')
              _showTextInputDialog(
                "Bangsa Baru",
                (val) => setState(() => _selectedIbBangsa = val),
              );
            else
              setState(() => _selectedIbBangsa = v);
          },
        ),
      ],
    );
  }

  Widget _buildFormPKB() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Hasil Cek:", style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Expanded(
              child: RadioListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Bunting"),
                value: "Bunting",
                groupValue: _pkbStatus,
                activeColor: Colors.purple,
                onChanged: (v) => setState(() => _pkbStatus = v),
              ),
            ),
            Expanded(
              child: RadioListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Tidak"),
                value: "Tidak",
                groupValue: _pkbStatus,
                activeColor: Colors.purple,
                onChanged: (v) => setState(() => _pkbStatus = v),
              ),
            ),
          ],
        ),
        if (_pkbStatus == 'Bunting') ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _pkbBulanController,
            keyboardType: TextInputType.number,
            decoration: _inputDecor("Usia Kebuntingan (Bulan)"),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecor(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.grey[50],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
  Widget _buildSectionTitle(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: Colors.purple, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    ),
  );
  Widget _buildCardContainer(Widget child) => Container(
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
  Widget _buildAddButton(VoidCallback? onTap) => InkWell(
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

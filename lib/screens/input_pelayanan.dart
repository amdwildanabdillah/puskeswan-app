import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InputPelayananScreen extends StatefulWidget {
  const InputPelayananScreen({super.key});

  @override
  State<InputPelayananScreen> createState() => _InputPelayananScreenState();
}

class _InputPelayananScreenState extends State<InputPelayananScreen> {
  final _supabase = Supabase.instance.client;

  // --- VARIABEL DATA ---
  String? _selectedPeternak;
  String _selectedHewan = 'Sapi';
  final _diagnosaController = TextEditingController();
  final _layananController = TextEditingController();
  final _biayaController = TextEditingController();

  // --- VARIABEL OBAT ---
  int? _selectedBarangId;

  List<Map<String, dynamic>> _listPeternak = [];
  List<Map<String, dynamic>> _listObat = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ambilDataAwal();
  }

  Future<void> _ambilDataAwal() async {
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

      if (mounted) {
        setState(() {
          _listPeternak = List<Map<String, dynamic>>.from(dataPeternak);
          _listObat = List<Map<String, dynamic>>.from(dataObat);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error Load Data: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _simpanLayanan() async {
    if (_selectedPeternak == null || _biayaController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Lengkapi data dulu!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      final emailDokter = user?.email ?? 'anonim';

      // 1. SIMPAN LAPORAN
      await _supabase.from('pelayanan').insert({
        'nama_peternak': _selectedPeternak,
        'jenis_hewan': _selectedHewan,
        'diagnosa': _diagnosaController.text,
        'jenis_layanan': _layananController.text,
        'biaya': int.parse(_biayaController.text),
        'dokter_email': emailDokter,
      });

      // 2. POTONG STOK
      if (_selectedBarangId != null) {
        final dataBarang = await _supabase
            .from('barang')
            .select('stok')
            .eq('id', _selectedBarangId!)
            .single();
        int stokSekarang = dataBarang['stok'] as int;

        if (stokSekarang > 0) {
          await _supabase
              .from('barang')
              .update({'stok': stokSekarang - 1})
              .eq('id', _selectedBarangId!);
        }
      }

      // 3. RESET FORM
      setState(() {
        _selectedPeternak = null;
        _selectedHewan = 'Sapi';
        _selectedBarangId = null;
        _isLoading = false;
      });
      _layananController.clear();
      _biayaController.clear();
      _diagnosaController.clear();

      _ambilDataAwal(); // Refresh stok

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Laporan Masuk & Stok Terupdate!")),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Input Pelayanan (Stok Auto)"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green[50],
                  child: Column(
                    children: [
                      // 1. PILIH PETERNAK (Fix Kriting Biru)
                      DropdownButtonFormField<String>(
                        key: ValueKey(_selectedPeternak),
                        initialValue:
                            _selectedPeternak, // <-- PAKAI initialValue
                        decoration: const InputDecoration(
                          labelText: "Pilih Peternak",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                        items: _listPeternak.map<DropdownMenuItem<String>>((
                          item,
                        ) {
                          return DropdownMenuItem<String>(
                            value: item['nama'].toString(),
                            child: Text(item['nama'].toString()),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedPeternak = val),
                      ),
                      const SizedBox(height: 10),

                      // 2. DATA HEWAN & SAKIT (Fix Overflow & Kriting Biru)
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(_selectedHewan),
                              initialValue:
                                  _selectedHewan, // <-- PAKAI initialValue
                              isExpanded:
                                  true, // <-- INI OBATNYA OVERFLOW BIAR RAPI
                              decoration: const InputDecoration(
                                labelText: "Hewan",
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 15,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                              ),
                              items: ['Sapi', 'Kambing', 'Kucing', 'Lainnya']
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedHewan = val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _diagnosaController,
                              decoration: const InputDecoration(
                                labelText: "Diagnosa",
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 3. TINDAKAN & OBAT
                      TextField(
                        controller: _layananController,
                        decoration: const InputDecoration(
                          labelText: "Tindakan (cth: Suntik/IB)",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // --- DROPDOWN OBAT (Fix Kriting Biru) ---
                      DropdownButtonFormField<int>(
                        key: ValueKey(_selectedBarangId),
                        initialValue:
                            _selectedBarangId, // <-- PAKAI initialValue
                        isExpanded: true, // Tambah ini juga biar aman
                        decoration: const InputDecoration(
                          labelText: "Pemakaian Stok (Opsional)",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                          helperText: "Stok akan berkurang 1 unit otomatis",
                          prefixIcon: Icon(
                            Icons.medication,
                            color: Colors.orange,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text(
                              "Tidak pakai stok gudang",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ..._listObat.map<DropdownMenuItem<int>>((item) {
                            return DropdownMenuItem<int>(
                              value: item['id'] as int,
                              child: Text(
                                "${item['nama_barang']} (Sisa: ${item['stok']})",
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedBarangId = val),
                      ),

                      const SizedBox(height: 10),

                      // 4. BIAYA
                      TextField(
                        controller: _biayaController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Biaya (Rp)",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                          prefixText: "Rp ",
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _simpanLayanan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            "SIMPAN LAPORAN",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- LIST RIWAYAT ---
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('pelayanan')
                        .stream(primaryKey: ['id'])
                        .order('waktu', ascending: false),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final data = snapshot.data!;
                      if (data.isEmpty) {
                        return const Center(child: Text("Belum ada data."));
                      }

                      return ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (ctx, i) {
                          final item = data[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.history, color: Colors.grey),
                            title: Text(
                              "${item['nama_peternak']} - ${item['jenis_layanan']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "Diagnosa: ${item['diagnosa']} (${item['jenis_hewan']})",
                            ),
                            trailing: Text(
                              "Rp ${item['biaya']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

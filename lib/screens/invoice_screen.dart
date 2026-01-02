import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_helper.dart';

class InvoiceScreen extends StatefulWidget {
  final String role; // 'Admin Gudang' atau 'Dokter Hewan'
  const InvoiceScreen({super.key, required this.role});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _allTransaksi = [];
  bool _isLoading = true;
  int _totalSangu = 0;

  // --- FILTER VARIABLES ---
  DateTime? _selectedDate; // Kalau null = Tampilkan Semua Tanggal
  String? _selectedDokterEmail; // Kalau null = Semua Dokter (Khusus Admin)
  List<String> _dokterList = ['Semua Dokter']; // List buat Dropdown

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchDokterList(); // Ambil daftar dokter dulu
    await _fetchHistory(); // Baru ambil transaksi
  }

  // 1. AMBIL LIST DOKTER (Buat Filter Admin)
  Future<void> _fetchDokterList() async {
    if (widget.role == 'Admin Gudang') {
      try {
        // Ambil email dokter unik dari tabel pelayanan (biar pasti ada datanya)
        final data = await _supabase.from('pelayanan').select('dokter_email');

        final List<String> emails = ['Semua Dokter'];
        for (var item in data) {
          final email = item['dokter_email'] as String;
          if (!emails.contains(email)) emails.add(email);
        }

        if (mounted) {
          setState(() {
            _dokterList = emails;
          });
        }
      } catch (e) {
        // Silent error
      }
    }
  }

  // 2. LOGIKA UTAMA: AMBIL DATA
  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final userEmail = _supabase.auth.currentUser?.email;

      // --- A. DATA ONLINE (Supabase) ---
      var queryBuilder = _supabase.from('pelayanan').select();

      // FILTER 1: TANGGAL
      if (_selectedDate != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        queryBuilder = queryBuilder
            .gte('waktu', '$dateStr 00:00:00')
            .lte('waktu', '$dateStr 23:59:59');
      }

      // FILTER 2: ROLE & DOKTER
      if (widget.role == 'Admin Gudang') {
        // Kalau Admin pilih dokter spesifik
        if (_selectedDokterEmail != null &&
            _selectedDokterEmail != 'Semua Dokter') {
          queryBuilder = queryBuilder.eq('dokter_email', _selectedDokterEmail!);
        }
      } else {
        // Kalau Dokter Biasa, WAJIB filter punya sendiri
        queryBuilder = queryBuilder.eq('dokter_email', userEmail!);
      }

      // EKSEKUSI QUERY
      final onlineData = await queryBuilder.order('waktu', ascending: false);

      // --- B. DATA OFFLINE (Local DB) ---
      final allOffline = await DatabaseHelper().getTransaksiPending();

      List<Map<String, dynamic>> gabungan = [];

      // Filter Data Offline secara Manual (Dart Logic)
      for (var item in allOffline) {
        bool passDate = true;
        bool passDokter = true;

        // Cek Tanggal Offline
        if (_selectedDate != null) {
          final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
          passDate = item['waktu'].toString().substring(0, 10) == dateStr;
        }

        // Cek Dokter Offline
        if (widget.role == 'Admin Gudang') {
          if (_selectedDokterEmail != null &&
              _selectedDokterEmail != 'Semua Dokter') {
            passDokter = item['dokter_email'] == _selectedDokterEmail;
          }
        } else {
          passDokter = item['dokter_email'] == userEmail;
        }

        if (passDate && passDokter) {
          final newItem = Map<String, dynamic>.from(item);
          newItem['status'] = 'offline';
          gabungan.add(newItem);
        }
      }

      // Masukkan Data Online
      for (var item in onlineData) {
        final newItem = Map<String, dynamic>.from(item);
        newItem['status'] = 'online';
        gabungan.add(newItem);
      }

      // Hitung Total
      int total = 0;
      for (var item in gabungan) {
        total += (item['biaya'] as num).toInt();
      }

      if (mounted) {
        setState(() {
          _allTransaksi = gabungan;
          _totalSangu = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Pop-up Pilih Tanggal
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: "Pilih Tanggal Laporan",
      cancelText: "Semua Waktu", // Tombol buat reset filter
      confirmText: "Pilih",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.purple),
          ),
          child: child!,
        );
      },
    );

    // Logika Reset: Kalau user klik "Semua Waktu" (biasanya cancel), kita null-kan
    // Tapi karena showDatePicker return null kalau cancel, kita perlu logika tombol khusus
    // Cara mudah: Kita pakai logika 'picked' biasa. Kalau user mau reset, kita kasih tombol silang di UI.
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchHistory();
    }
  }

  Future<void> _exportCsv() async {
    if (_allTransaksi.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Data kosong!")));
      return;
    }
    try {
      List<List<dynamic>> rows = [];
      rows.add([
        "Tanggal",
        "Jam",
        "Dokter",
        "Peternak",
        "Hewan",
        "Detail",
        "Keluhan",
        "Diagnosa",
        "Tindakan",
        "Biaya",
        "Status",
      ]);

      for (var item in _allTransaksi) {
        rows.add([
          item['waktu'].toString().substring(0, 10),
          _formatJam(item['waktu']),
          item['dokter_email'],
          item['nama_peternak'],
          item['jenis_hewan'],
          item['detail_hewan'],
          item['anamnesa'],
          item['diagnosa'],
          item['jenis_layanan'],
          item['biaya'],
          item['status'],
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final dateLabel = _selectedDate == null
          ? "Semua_Waktu"
          : DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final path = "${directory.path}/Laporan_Puskeswan_$dateLabel.csv";

      final file = File(path);
      await file.writeAsString(csvData);
      await Share.shareXFiles([
        XFile(path),
      ], text: 'Laporan Puskeswan ($dateLabel)');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal Export: $e")));
    }
  }

  String _formatRupiah(int nominal) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(nominal);

  String _formatJam(String isoDate) {
    try {
      return DateFormat('HH:mm').format(DateTime.parse(isoDate));
    } catch (e) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Invoice & Sangu",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.purple),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. FILTER AREA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // A. FILTER TANGGAL
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.purple),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Filter Tanggal:",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                _selectedDate == null
                                    ? "Semua Riwayat"
                                    : DateFormat(
                                        'dd MMMM yyyy',
                                        'id_ID',
                                      ).format(_selectedDate!),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedDate != null)
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() => _selectedDate = null);
                              _fetchHistory();
                            },
                          )
                        else
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                // B. FILTER DOKTER (HANYA MUNCUL JIKA ADMIN)
                if (widget.role == 'Admin Gudang') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple[100]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDokterEmail ?? 'Semua Dokter',
                        isExpanded: true,
                        icon: const Icon(
                          Icons.person_search,
                          color: Colors.purple,
                        ),
                        items: _dokterList.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value == 'Semua Dokter'
                                  ? "Semua Dokter"
                                  : "Dr. ${value.split('@')[0]}",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.purple[900],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() => _selectedDokterEmail = newValue);
                          _fetchHistory();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. KARTU SANGU
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? "Total Pendapatan (Akumulasi)"
                            : "Total Pendapatan Tanggal Ini",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _formatRupiah(_totalSangu),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${_allTransaksi.length} Data Transaksi",
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // 3. LIST TRANSAKSI
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allTransaksi.isEmpty
                ? Center(
                    child: Text(
                      "Data tidak ditemukan",
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: _allTransaksi.length,
                    itemBuilder: (context, index) {
                      final item = _allTransaksi[index];
                      final isOffline = item['status'] == 'offline';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isOffline
                                    ? Colors.orange[50]
                                    : Colors.purple[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isOffline ? Icons.wifi_off : Icons.pets,
                                color: isOffline
                                    ? Colors.orange
                                    : Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['nama_peternak'] ?? '-',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "${item['jenis_hewan']} • ${item['jenis_layanan']}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (widget.role == 'Admin Gudang')
                                    Text(
                                      "Dr. ${item['dokter_email']?.split('@')[0]}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.purple,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatRupiah((item['biaya'] as num).toInt()),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  item['waktu'].toString().substring(0, 10),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

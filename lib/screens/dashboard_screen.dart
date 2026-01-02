import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/database_helper.dart';

import 'login_screen.dart';
import 'gudang_screen.dart';
import 'input_pelayanan.dart';
import 'invoice_screen.dart';
import 'data_peternak_screen.dart';
import 'about_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  final String nama;

  const DashboardScreen({super.key, required this.role, required this.nama});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _pendingDataCount = 0;
  bool _isSyncing = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkPendingData();
  }

  void _refreshDashboard() {
    _checkPendingData();
  }

  Future<void> _checkPendingData() async {
    final count = await DatabaseHelper().countPending();
    if (mounted) setState(() => _pendingDataCount = count);
  }

  // --- LOGIKA SYNC (UPLOAD DATA OFFLINE) ---
  Future<void> _syncNow() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tidak ada internet!")));
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final db = DatabaseHelper();
      final pendingList = await db.getTransaksiPending();

      for (var item in pendingList) {
        final dataToUpload = Map<String, dynamic>.from(item);
        dataToUpload.remove('id'); // Hapus ID lokal

        await Supabase.instance.client.from('pelayanan').insert(dataToUpload);
        await db.deleteTransaksi(
          item['id'],
        ); // Hapus dari HP kalau udah sukses upload
      }

      _checkPendingData();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sync Berhasil! Data Offline Terupload."),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync Gagal: $e"),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
  }

  // --- NAVIGASI FIX (ABOUT CUMA NUMPANG LEWAT) ---
  void _onItemTapped(int index) {
    if (index == 0) {
      setState(() => _selectedIndex = 0);
    } else if (index == 1) {
      // JANGAN UBAH _selectedIndex BIAR NAVIGASI TETAP DI HOME
      _showSimpleAboutDialog();
    } else if (index == 2) {
      setState(() => _selectedIndex = 2);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AboutScreen(),
        ), // Ke Halaman Profil
      ).then((_) {
        // Pas balik, reset ke Home
        setState(() => _selectedIndex = 0);
      });
    }
  }

  void _showSimpleAboutDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 50, color: Colors.purple),
            const SizedBox(height: 16),
            Text(
              "Puskeswan Mobile v1.0",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Aplikasi Manajemen Pelayanan Kesehatan Hewan",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text(
              "© 2026 Vixel Creative",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.purple[50],
              child: Text(
                widget.nama.isNotEmpty ? widget.nama[0].toUpperCase() : "U",
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Halo, ${widget.nama}",
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.role,
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.grey),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BANNER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Puskeswan\nTrenggalek",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4A148C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Kelola data kesehatan hewan dengan mudah.",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF7B1FA2),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const InputPelayananScreen(),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7B1FA2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Mulai",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.pets,
                    size: 80,
                    color: Colors.purple.withOpacity(0.2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ALERT SYNC (KOTAK ORANYE)
            if (_pendingDataCount > 0)
              InkWell(
                onTap: _syncNow,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      _isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.orange,
                              ),
                            )
                          : const Icon(
                              Icons.cloud_upload,
                              color: Colors.orange,
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "$_pendingDataCount Data Offline (Belum Terkirim)",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                      const Text(
                        "Upload",
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // MENU GRID
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildUizardCard(
                  context,
                  "Stok Gudang",
                  Icons.inventory_2_rounded,
                  Colors.blue,
                  GudangScreen(role: widget.role),
                ),
                _buildUizardCard(
                  context,
                  "Data Peternak",
                  Icons.people_alt_rounded,
                  Colors.orange,
                  DataPeternakScreen(role: widget.role),
                ),
                _buildUizardCard(
                  context,
                  "Input Pelayanan",
                  Icons.add_circle_rounded,
                  Colors.purple,
                  const InputPelayananScreen(),
                  isPrimary: true,
                  needRefresh: true,
                ),
                _buildUizardCard(
                  context,
                  "Invoice",
                  Icons.receipt_long_rounded,
                  Colors.green,
                  InvoiceScreen(role: widget.role),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF7B1FA2),
        unselectedItemColor: Colors.grey[400],
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline_rounded),
            label: "About",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  Widget _buildUizardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget page, {
    bool isPrimary = false,
    bool needRefresh = false,
  }) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
        if (needRefresh) _refreshDashboard();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: isPrimary ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

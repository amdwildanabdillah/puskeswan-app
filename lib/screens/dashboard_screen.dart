import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import Screen Lainnya
import 'login_screen.dart';
import 'gudang_screen.dart';
import 'input_pelayanan.dart';
import 'invoice_screen.dart';
import 'data_peternak_screen.dart';
import 'about_screen.dart'; // <--- Pastikan file about_screen.dart sudah dibuat

class DashboardScreen extends StatelessWidget {
  final String role; // 'Admin Gudang' atau 'Dokter Hewan'
  final String nama; // Nama user yang login

  const DashboardScreen({super.key, required this.role, required this.nama});

  // Fungsi Logout
  Future<void> _logout(BuildContext context) async {
    // Tampilkan konfirmasi dulu biar gak kepencet
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Logout"),
        content: const Text("Yakin ingin keluar dari aplikasi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Keluar"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50], // Background ungu muda
      appBar: AppBar(
        title: const Text(
          "Puskeswan Trenggalek",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.purple[800], // Warna Ungu Tua
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // TOMBOL INFO (ABOUT VIXEL)
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: "Tentang Aplikasi",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),

          // TOMBOL LOGOUT
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Keluar",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // HEADER PROFIL (Desain Curve)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
            decoration: BoxDecoration(
              color: Colors.purple[800],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar Inisial
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    nama.isNotEmpty ? nama[0].toUpperCase() : "P",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Info Nama & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Selamat Bertugas,",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nama,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // GRID MENU UTAMA
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(24),
              crossAxisCount: 2, // 2 Kolom
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                // 1. STOK GUDANG
                _buildMenuCard(
                  context,
                  "Stok Gudang",
                  Icons.warehouse,
                  Colors.orange,
                  GudangScreen(role: role),
                ),

                // 2. DATA PETERNAK
                _buildMenuCard(
                  context,
                  "Data Peternak",
                  Icons.people,
                  Colors.blue,
                  DataPeternakScreen(role: role),
                ),

                // 3. INPUT PELAYANAN (Penting!)
                _buildMenuCard(
                  context,
                  "Input Pelayanan",
                  Icons.pets,
                  Colors.purple,
                  const InputPelayananScreen(),
                ),

                // 4. INVOICE SANGU
                _buildMenuCard(
                  context,
                  "Invoice Sangu",
                  Icons.attach_money,
                  Colors.green,
                  InvoiceScreen(role: role),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET KARTU MENU BIAR RAPI
  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      borderRadius: BorderRadius.circular(20),
      child: Card(
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

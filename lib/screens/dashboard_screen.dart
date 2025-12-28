import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'gudang_screen.dart';
import 'input_pelayanan.dart';
import 'invoice_screen.dart';
import 'data_peternak_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String role; // 'Admin Gudang' atau 'Dokter Hewan'

  const DashboardScreen({super.key, required this.role});

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Puskeswan App"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Keluar",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Profil
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.green[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Halo, Selamat Bertugas",
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // Grid Menu
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                // 1. STOK GUDANG (Kirim Role)
                _buildMenuCard(
                  context,
                  "Stok Gudang",
                  Icons.warehouse,
                  Colors.orange,
                  GudangScreen(role: role),
                ),

                // 2. DATA PETERNAK (Kirim Role)
                _buildMenuCard(
                  context,
                  "Data Peternak",
                  Icons.people,
                  Colors.blue,
                  DataPeternakScreen(role: role),
                ),

                // 3. INPUT PELAYANAN (Semua Bisa)
                _buildMenuCard(
                  context,
                  "Input Pelayanan",
                  Icons.pets,
                  Colors.purple,
                  const InputPelayananScreen(),
                ),

                // 4. INVOICE SANGU (Kirim Role -> INI YANG PENTING)
                _buildMenuCard(
                  context,
                  "Invoice Sangu",
                  Icons.attach_money,
                  Colors.teal,
                  InvoiceScreen(role: role),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

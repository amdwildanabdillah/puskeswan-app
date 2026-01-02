import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isObscure = true;

  // Fungsi Login Email
  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        _checkUserAndNavigate(response.user!.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login Gagal: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi Login Google (Tambahan)
  Future<void> _googleSignIn() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://callback',
      );
      // Note: Supabase akan otomatis handle redirect balik ke aplikasi
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Cek Role & Pindah Halaman
  Future<void> _checkUserAndNavigate(String userId) async {
    try {
      final userParams = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              role: userParams['role'] ?? 'Petugas',
              nama: userParams['full_name'] ?? 'User',
            ),
          ),
        );
      }
    } catch (e) {
      // Handle jika profile belum ada
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pets,
                      size: 40,
                      color: Colors.purple,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Text(
                        "Selamat Datang!",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Silakan masuk untuk melanjutkan",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 2. FORM INPUT
                Text(
                  "Email",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: "Masukan email dinas...",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Password",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    contentPadding: const EdgeInsets.all(16),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Lupa Password?",
                    style: GoogleFonts.poppins(
                      color: Colors.purple,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 3. TOMBOL LOGIN EMAIL
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shadowColor: Colors.purple.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "Masuk Sistem",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // 4. PEMBATAS (ATAU)
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "ATAU",
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 24),

                // 5. TOMBOL LOGIN GOOGLE (Baru)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _googleSignIn,
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                      height: 24,
                    ),
                    label: Text(
                      "Masuk dengan Google",
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                Center(
                  child: Text(
                    "Puskeswan Trenggalek v1.0",
                    style: GoogleFonts.poppins(
                      color: Colors.grey[300],
                      fontSize: 12,
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
}

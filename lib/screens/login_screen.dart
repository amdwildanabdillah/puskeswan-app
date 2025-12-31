import 'package:flutter/foundation.dart'; // Buat kIsWeb
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';
import 'verification_screen.dart'; // <--- JANGAN LUPA INI (Pastikan file verification_screen.dart sudah dibuat)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Akses Supabase
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _navigateToDashboard();
      }
    });
  }

  // --- LOGIKA BARU: CEK DATABASE DULU SEBELUM MASUK ---
  Future<void> _navigateToDashboard() async {
    if (!mounted) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Kasih tau user kalau sistem lagi mikir (biar gak dikira nge-hang)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sedang memeriksa status akun..."),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // 2. AMBIL DATA DARI TABEL PROFILES (YANG ADA STATUS PENDING-NYA)
      final data = await _supabase
          .from('profiles')
          .select('role, full_name')
          .eq('id', user.id)
          .maybeSingle(); // Pakai maybeSingle biar gak crash kalau data belum siap

      if (!mounted) return;

      // Kalau data belum ada (misal delay internet), anggap Pending dulu biar aman
      String role = data?['role'] ?? 'Pending';
      String nama = data?['full_name'] ?? 'User Baru';

      // 3. CEK DISINI: PENDING ATAU DOKTER?
      if (role == 'Pending') {
        // --- A. Kalau Pending -> LEMPAR KE RUANG TUNGGU ---
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerificationScreen(nama: nama),
          ),
        );
      } else {
        // --- B. Kalau Dokter/Admin -> MASUK DASHBOARD ---
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(role: role)),
        );
      }
    } catch (e) {
      // Kalau error koneksi atau lainnya, buang ke VerificationScreen demi keamanan
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const VerificationScreen(nama: "User"),
          ),
        );
      }
    }
  }

  // --- FUNCTION LOGIN GOOGLE ---
  Future<void> _loginWithGoogle() async {
    try {
      // Cek apakah aplikasi jalan di Web atau HP
      String redirectUrl = kIsWeb
          ? 'https://puskeswan-app.vercel.app/' // <--- Pastikan link Vercel ini benar
          : 'io.supabase.flutter://login-callback';

      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google Login Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi email dan password dulu!")),
      );
      return;
    }

    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Terjadi kesalahan sistem"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user,
                      size: 80,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Pusat Kesehatan Hewan",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Masukkan akun terdaftar",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        hintText: "nama@puskeswan.com",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Password",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Sign In",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text("ATAU"),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _loginWithGoogle,
                        icon: const Icon(
                          Icons.g_mobiledata,
                          size: 30,
                          color: Colors.red,
                        ),
                        label: const Text(
                          "Masuk dengan Google",
                          style: TextStyle(color: Colors.black87),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

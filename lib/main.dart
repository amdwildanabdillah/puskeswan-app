import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- INI KABEL KONEKSINYA ---
  // Pastikan URL dan Key diapit tanda kutip ' '
  await Supabase.initialize(
    url: 'https://bhiekftykdnywpuicqwy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJoaWVrZnR5a2RueXdwdWljcXd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY5MDk1NTMsImV4cCI6MjA4MjQ4NTU1M30.rZRoVVoockP-HLXqrzGdwygE-8cYNpcj6im2aN9ZqlA',
  );

  runApp(const PuskeswanApp());
}

class PuskeswanApp extends StatelessWidget {
  const PuskeswanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UPT PUSKESWAN TRENGGALEK',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

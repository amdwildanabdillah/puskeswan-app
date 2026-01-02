import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'detail_peternak_screen.dart'; // Jangan lupa import

class DataPeternakScreen extends StatefulWidget {
  final String role;
  const DataPeternakScreen({super.key, required this.role});

  @override
  State<DataPeternakScreen> createState() => _DataPeternakScreenState();
}

class _DataPeternakScreenState extends State<DataPeternakScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _peternakList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPeternak();
  }

  Future<void> _fetchPeternak() async {
    try {
      final data = await _supabase
          .from('peternak')
          .select()
          .order('nama', ascending: true);
      setState(() {
        _peternakList = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Uizard White
      appBar: AppBar(
        title: Text(
          "Data Peternak",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _peternakList.length,
              itemBuilder: (context, index) {
                final peternak = _peternakList[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    // FITUR KLIK KE DETAIL
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DetailPeternakScreen(peternak: peternak),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: Text(
                              peternak['nama'][0].toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  peternak['nama'],
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  peternak['alamat'] ?? 'Alamat belum diisi',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Tambahkan logika tambah peternak di sini nanti
        },
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

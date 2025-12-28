class UserModel {
  final String id;
  final String username;
  final String role; // 'admin' atau 'dokter'
  final String namaLengkap;

  UserModel({
    required this.id,
    required this.username,
    required this.role,
    required this.namaLengkap,
  });

  // Nanti dipakai saat ambil data dari Database (JSON)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      namaLengkap: json['nama_lengkap'],
    );
  }
}

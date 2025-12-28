class BarangModel {
  final String id;
  final String namaBarang;
  final String jenis; // 'Obat', 'Pakan', 'Alat'
  final int stok;
  final double harga;

  BarangModel({
    required this.id,
    required this.namaBarang,
    required this.jenis,
    required this.stok,
    required this.harga,
  });

  // Mengubah data JSON dari database menjadi Object Barang
  factory BarangModel.fromJson(Map<String, dynamic> json) {
    return BarangModel(
      id: json['id'],
      namaBarang: json['nama_barang'],
      jenis: json['jenis'],
      stok: json['stok'],
      harga: json['harga'].toDouble(),
    );
  }
}

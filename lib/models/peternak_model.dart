class PeternakModel {
  final String id;
  final String nama;
  final String alamat;
  final String noHp;

  PeternakModel({
    required this.id,
    required this.nama,
    required this.alamat,
    required this.noHp,
  });

  factory PeternakModel.fromJson(Map<String, dynamic> json) {
    return PeternakModel(
      id: json['id'],
      nama: json['nama'],
      alamat: json['alamat'],
      noHp: json['no_hp'],
    );
  }
}

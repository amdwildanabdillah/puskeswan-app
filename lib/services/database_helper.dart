import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'puskeswan_local.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transaksi_pending(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dokter_email TEXT,
            nama_peternak TEXT,
            jenis_hewan TEXT,   -- TAMBAHAN
            detail_hewan TEXT,
            jumlah_hewan INTEGER,
            diagnosa TEXT,      -- TAMBAHAN
            jenis_layanan TEXT,
            biaya INTEGER,
            waktu TEXT
          )
        ''');
      },
    );
  }

  // 1. Simpan Transaksi ke HP (Kalau Offline)
  Future<int> insertTransaksi(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('transaksi_pending', row);
  }

  // 2. Ambil Semua Data Pending (Buat di-upload nanti)
  Future<List<Map<String, dynamic>>> getTransaksiPending() async {
    Database db = await database;
    return await db.query('transaksi_pending');
  }

  // 3. Hapus Data Pending (Kalau udah sukses upload)
  Future<int> deleteTransaksi(int id) async {
    Database db = await database;
    return await db.delete(
      'transaksi_pending',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 4. Hitung Jumlah Data Pending (Buat lencana notifikasi)
  Future<int> countPending() async {
    Database db = await database;
    var result = await db.rawQuery('SELECT COUNT(*) FROM transaksi_pending');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

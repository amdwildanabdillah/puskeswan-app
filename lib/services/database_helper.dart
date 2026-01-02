import 'package:flutter/foundation.dart' show kIsWeb; // <--- INI KUNCINYA
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database?> get database async {
    // KALAU DI WEB, KITA "MATIKAN" DATABASE LOKALNYA
    if (kIsWeb) return null;

    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'puskeswan_local_v4.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transaksi_pending(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dokter_email TEXT,
            nama_peternak TEXT,
            jenis_hewan TEXT,
            detail_hewan TEXT,
            jumlah_hewan INTEGER,
            anamnesa TEXT,
            diagnosa TEXT,
            jenis_layanan TEXT,
            biaya INTEGER,
            waktu TEXT
          )
        ''');
      },
    );
  }

  // SEMUA FUNGSI DI BAWAH DIKASIH REM 'kIsWeb'
  Future<int> insertTransaksi(Map<String, dynamic> row) async {
    if (kIsWeb) return 0;
    Database? db = await database;
    return await db!.insert('transaksi_pending', row);
  }

  Future<List<Map<String, dynamic>>> getTransaksiPending() async {
    if (kIsWeb) return [];
    Database? db = await database;
    return await db!.query('transaksi_pending');
  }

  Future<int> deleteTransaksi(int id) async {
    if (kIsWeb) return 0;
    Database? db = await database;
    return await db!.delete(
      'transaksi_pending',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countPending() async {
    if (kIsWeb) return 0;
    Database? db = await database;
    var result = await db!.rawQuery('SELECT COUNT(*) FROM transaksi_pending');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

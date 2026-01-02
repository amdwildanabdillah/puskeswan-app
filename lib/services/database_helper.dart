import 'dart:io'; // PENTING: Buat cek Platform
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database?> get database async {
    // REVISI: Matikan DB Lokal kalau Web ATAU Linux/Windows/Mac
    // Biar gak error "MissingPlugin" pas develop di PC
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return null;
    }

    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Naikkan versi jadi v6 biar aman
    String path = join(await getDatabasesPath(), 'puskeswan_local_v6.db');
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
            kategori_layanan TEXT, 
            kode_straw TEXT,
            obat_1 TEXT,
            obat_2 TEXT,
            obat_3 TEXT,
            obat_4 TEXT,
            obat_5 TEXT,
            biaya INTEGER,
            waktu TEXT
          )
        ''');
      },
    );
  }

  // --- CEK PLATFORM DI SEMUA FUNGSI ---

  Future<int> insertTransaksi(Map<String, dynamic> row) async {
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS)
      return 0;

    Database? db = await database;
    if (db == null) return 0;
    return await db.insert('transaksi_pending', row);
  }

  Future<List<Map<String, dynamic>>> getTransaksiPending() async {
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS)
      return [];

    Database? db = await database;
    if (db == null) return [];
    return await db.query('transaksi_pending');
  }

  Future<int> deleteTransaksi(int id) async {
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS)
      return 0;

    Database? db = await database;
    if (db == null) return 0;
    return await db.delete(
      'transaksi_pending',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countPending() async {
    if (kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS)
      return 0;

    Database? db = await database;
    if (db == null) return 0;
    var result = await db.rawQuery('SELECT COUNT(*) FROM transaksi_pending');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  Database? _db;

  Future<void> init() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docDir.path, 'lismey.db');
      _db = await openDatabase(dbPath, version: 1, onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS findunit (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            macadress TEXT
          )
        ''');
      });

      // Ensure 'mydevice' table exists in the database
      if (_db != null) {
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS mydevice (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            macadress TEXT,
            battery INTEGER
          )
        ''');
        try {
          await _db!.execute('ALTER TABLE mydevice ADD COLUMN battery INTEGER');
        } catch (_) {}
      }

      // Ensure 'mymeeteng' table exists in the database
      if (_db != null) {
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS mymeeteng (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            mac TEXT,
            owner_id TEXT
          )
        ''');
      }
    } catch (_) {}
  }

  Future<void> clearFindUnit() async {
    if (_db == null) return;
    try {
      await _db!.delete('findunit');
    } catch (_) {}
  }

  Future<void> saveFindUnits(List<ScanResult> results, {Map<String, String>? decodedNames}) async {
    if (_db == null) return;
    final batch = _db!.batch();
    for (final r in results) {
      final mac = r.device.id.id;
      final name = (decodedNames != null && decodedNames.containsKey(mac))
          ? decodedNames[mac]!
          : (r.device.name.isNotEmpty
              ? r.device.name
              : r.advertisementData.localName.isNotEmpty
                  ? r.advertisementData.localName
                  : 'Unknown device');
      batch.insert('findunit', {'name': name, 'macadress': mac},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    try {
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadFindUnits() async {
    if (_db == null) return [];
    try {
      return await _db!.query('findunit');
    } catch (_) {
      return [];
    }
  }

  // --- MYDEVICE TABLE OPERATIONS ---

  Future<void> saveMyDevice(String name, String macAdress, {int? battery}) async {
    if (_db == null) return;
    try {
      // Avoid duplicates: check if this macadress is already registered
      final existing = await _db!.query('mydevice', where: 'macadress = ?', whereArgs: [macAdress]);
      if (existing.isEmpty) {
        await _db!.insert('mydevice', {
          'name': name,
          'macadress': macAdress,
          'battery': battery,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await _db!.update('mydevice', {
          'name': name,
          'battery': battery,
        }, where: 'macadress = ?', whereArgs: [macAdress]);
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadMyDevices() async {
    if (_db == null) return [];
    try {
      return await _db!.query('mydevice');
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteMyDevice(int id) async {
    if (_db == null) return;
    try {
      await _db!.delete('mydevice', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // --- MYMEETENG TABLE OPERATIONS ---

  Future<void> saveMetDevice(String name, String mac, String ownerId) async {
    if (_db == null) return;
    try {
      // Avoid duplicates: check if this mac is already registered
      final existing = await _db!.query('mymeeteng', where: 'mac = ?', whereArgs: [mac]);
      if (existing.isEmpty) {
        await _db!.insert('mymeeteng', {
          'name': name,
          'mac': mac,
          'owner_id': ownerId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadMetDevices() async {
    if (_db == null) return [];
    try {
      return await _db!.query('mymeeteng');
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteMetDevice(int id) async {
    if (_db == null) return;
    try {
      await _db!.delete('mymeeteng', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  bool get isReady => _db != null;
}


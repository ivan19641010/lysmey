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

      if (_db != null) {
        // --- NEW SCHEMAS ---

        // 1. self_accounts: always only one record after registration
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS self_accounts (
            id TEXT PRIMARY KEY,
            phone TEXT,
            password TEXT,
            name TEXT UNIQUE,
            email TEXT,
            birthdate TEXT,
            residence TEXT
          )
        ''');

        // 2. accounts
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE,
            birthdate TEXT,
            residence TEXT,
            active INTEGER DEFAULT 0,
            sympathy INTEGER DEFAULT 0
          )
        ''');

        // 3. self_units
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS self_units (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            btname TEXT,
            password TEXT,
            version INTEGER DEFAULT 1,
            lost INTEGER DEFAULT 0,
            faulty INTEGER DEFAULT 0,
            battery INTEGER,
            macadress TEXT
          )
        ''');

        // 4. units
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS units (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            btname TEXT,
            account TEXT,
            mac TEXT
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
      final mac = r.device.remoteId.str;
      final name = (decodedNames != null && decodedNames.containsKey(mac))
          ? decodedNames[mac]!
          : (r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName.isNotEmpty
                  ? r.advertisementData.advName
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

  // --- SELF_ACCOUNTS TABLE OPERATIONS ---

  Future<void> saveSelfAccount({
    required String id,
    required String name,
    required String email,
    String? phone,
    String? password,
    String? birthdate,
    String? residence,
  }) async {
    if (_db == null) return;
    try {
      await _db!.insert('self_accounts', {
        'id': id,
        'phone': phone ?? '',
        'password': password ?? '',
        'name': name,
        'email': email,
        'birthdate': birthdate ?? '',
        'residence': residence ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getSelfAccount() async {
    if (_db == null) return null;
    try {
      final list = await _db!.query('self_accounts', limit: 1);
      if (list.isNotEmpty) {
        return list[0];
      }
    } catch (_) {}
    return null;
  }

  // --- SELF_UNITS TABLE OPERATIONS (Own Devices) ---

  Future<void> saveMyDevice(String name, String macAdress, {int? battery, String? password}) async {
    if (_db == null) return;
    try {
      final existing = await _db!.query('self_units', where: 'macadress = ?', whereArgs: [macAdress]);
      if (existing.isEmpty) {
        await _db!.insert('self_units', {
          'btname': name,
          'macadress': macAdress,
          'battery': battery,
          'password': password ?? '',
          'version': 1,
          'lost': 0,
          'faulty': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await _db!.update('self_units', {
          'btname': name,
          'battery': battery,
          if (password != null) 'password': password,
        }, where: 'macadress = ?', whereArgs: [macAdress]);
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadMyDevices() async {
    if (_db == null) return [];
    try {
      final list = await _db!.query('self_units');
      return list.map((item) {
        return {
          'id': item['id'],
          'name': item['btname'], // map to legacy 'name'
          'macadress': item['macadress'], // map to legacy 'macadress'
          'battery': item['battery'],
          'password': item['password'],
          'version': item['version'],
          'lost': item['lost'],
          'faulty': item['faulty'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteMyDevice(int id) async {
    if (_db == null) return;
    try {
      await _db!.delete('self_units', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  // --- UNITS & ACCOUNTS TABLE OPERATIONS (Met Devices) ---

  Future<void> saveMetDevice(String name, String mac, String ownerId) async {
    if (_db == null) return;
    try {
      // 1. Save / update account
      final existingAccount = await _db!.query('accounts', where: 'id = ?', whereArgs: [ownerId]);
      if (existingAccount.isEmpty) {
        await _db!.insert('accounts', {
          'id': ownerId,
          'name': 'Пользователь $ownerId',
          'active': 1,
          'sympathy': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await _db!.update('accounts', {
          'active': 1,
        }, where: 'id = ?', whereArgs: [ownerId]);
      }

      // 2. Save unit
      final existingUnit = await _db!.query('units', where: 'mac = ?', whereArgs: [mac]);
      if (existingUnit.isEmpty) {
        await _db!.insert('units', {
          'btname': name,
          'account': ownerId,
          'mac': mac,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadMetDevices() async {
    if (_db == null) return [];
    try {
      final list = await _db!.rawQuery('''
        SELECT u.id, u.btname, u.mac, u.account as owner_id, a.name as owner_name, a.sympathy
        FROM units u
        LEFT JOIN accounts a ON u.account = a.id
      ''');
      return list.map((item) {
        return {
          'id': item['id'],
          'name': item['btname'], // map to legacy 'name'
          'mac': item['mac'],
          'owner_id': item['owner_id'] ?? 'N/A',
          'owner_name': item['owner_name'] ?? 'Пользователь ${item['owner_id']}',
          'sympathy': item['sympathy'] ?? 0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteMetDevice(int id) async {
    if (_db == null) return;
    try {
      final unitList = await _db!.query('units', columns: ['account'], where: 'id = ?', whereArgs: [id]);
      if (unitList.isNotEmpty) {
        final accountId = unitList[0]['account'];
        await _db!.delete('units', where: 'id = ?', whereArgs: [id]);
        if (accountId != null) {
          final remaining = await _db!.query('units', where: 'account = ?', whereArgs: [accountId]);
          if (remaining.isEmpty) {
            await _db!.delete('accounts', where: 'id = ?', whereArgs: [accountId]);
          }
        }
      }
    } catch (_) {}
  }

  bool get isReady => _db != null;
}

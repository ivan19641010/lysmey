import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_service.dart';
import '../services/database_service.dart';
import '../services/decoder_service.dart';
import '../services/supabase_service.dart';
import 'registration_screen.dart';

class BluetoothScanScreen extends StatefulWidget {
  final bool autoStartScan;
  const BluetoothScanScreen({super.key, this.autoStartScan = false});

  @override
  State<BluetoothScanScreen> createState() => _BluetoothScanScreenState();
}

class _BluetoothScanScreenState extends State<BluetoothScanScreen> {
  final _ble = BleService();
  final _db = DatabaseService();

  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectedDeviceName;
  String? _connectedDeviceMac;
  String _scanMessage = '';
  List<ScanResult> _filteredResults = [];
  bool _savedToDb = false;
  List<Map<String, dynamic>> _dbItems = [];
  final _supabase = SupabaseService();

  final Map<String, String?> _deviceAvailability = {};
  final Set<String> _checkingDevices = {};

  StreamSubscription<String>? _receivedDataSubscription;
  String? _batteryLevel;

  @override
  void initState() {
    super.initState();
    _initAndScan();
    _ble.onResults = (_) => _updateFilteredResults(saveToDb: false);

    // Подписываемся на входящие уведомления от устройства (уровень батареи)
    _receivedDataSubscription = _ble.receivedDataStream.listen((data) {
      setState(() {
        _batteryLevel = data;
        _scanMessage = 'Устройство готово к регистрации.';
      });
    });
  }

  Future<void> _initAndScan() async {
    await _db.init();
    if (widget.autoStartScan) {
      _startScan();
    }
  }

  @override
  void dispose() {
    _receivedDataSubscription?.cancel();
    _ble.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    await _db.clearFindUnit();
    setState(() {
      _isScanning = true;
      _scanMessage = '';
      _savedToDb = false;
      _dbItems = [];
      _filteredResults = [];
      _batteryLevel = null;
    });

    final error = await _ble.startScan(duration: const Duration(seconds: 15));

    if (error != null) {
      setState(() {
        _scanMessage = error;
        _isScanning = false;
      });
      return;
    }

    setState(() => _isScanning = false);
    await _updateFilteredResults(saveToDb: true);
  }

  Future<void> _checkAndSaveMetDevice(String rawName, String mac, String ownerId) async {
    final myDevices = await _db.loadMyDevices();
    final isMine = myDevices.any((d) => d['name'] == rawName || d['macadress'] == mac);
    if (!isMine) {
      await _db.saveMetDevice(rawName, mac, ownerId);
    }
  }

  Future<void> _updateFilteredResults({bool saveToDb = true}) async {
    final List<ScanResult> filtered = [];
    final Map<String, String> decodedNames = {};

    for (final r in _ble.allResults) {
      final rawName = r.device.name.isNotEmpty
          ? r.device.name
          : r.advertisementData.localName.isNotEmpty
              ? r.advertisementData.localName
              : '';

      if (rawName.length == 8) {
        final decoded = DecoderService.decodeInt(rawName);
        if (decoded != 0) {
          if (_deviceAvailability.containsKey(rawName)) {
            final ownerId = _deviceAvailability[rawName];
            if (ownerId == null) {
              filtered.add(r);
              decodedNames[r.device.id.id] = decoded.toString();
            } else {
              _checkAndSaveMetDevice(rawName, r.device.id.id, ownerId);
            }
          } else {
            if (!_checkingDevices.contains(rawName)) {
              _checkingDevices.add(rawName);
              _supabase.getUnitAccountId(rawName).then((accountId) {
                _deviceAvailability[rawName] = accountId;
                _checkingDevices.remove(rawName);
                if (accountId != null) {
                  _checkAndSaveMetDevice(rawName, r.device.id.id, accountId);
                }
                _updateFilteredResults(saveToDb: saveToDb);
              }).catchError((e) {
                // Если устройство не найдено в Supabase или произошла ошибка
                _deviceAvailability[rawName] = null;
                _checkingDevices.remove(rawName);
              });
            }
          }
        }
      }
    }

    setState(() => _filteredResults = filtered);

    if (saveToDb && filtered.isNotEmpty) {
      await _db.saveFindUnits(filtered);
      final items = await _db.loadFindUnits();
      setState(() {
        _dbItems = items;
        _savedToDb = true;
      });
    }
  }

  void _navigateToRegistration(String? deviceName, String? macAddress, String? batteryLevel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegistrationScreen(
          deviceName: deviceName,
          macAddress: macAddress,
          batteryLevel: batteryLevel,
        ),
      ),
    );
  }

  Future<void> _connectAndPrepare(String rawName, String macAddress) async {
    if (_isConnecting) return;

    if (_connectedDeviceName != null) {
      if (_connectedDeviceName == rawName) {
        // Если это то же самое устройство, которое уже готово к регистрации, ничего не делаем
        return;
      }
      
      // Если выбрано другое устройство после готовности к регистрации,
      // сбрасываем текущее соединение и устанавливаем заново для нового устройства
      setState(() {
        _scanMessage = 'Сброс соединения с $_connectedDeviceName...';
      });
      await _ble.disconnect();
      setState(() {
        _connectedDeviceName = null;
        _connectedDeviceMac = null;
      });
    }

    setState(() {
      _isConnecting = true;
      _scanMessage = 'Получение пароля...';
      _connectedDeviceName = null;
      _connectedDeviceMac = null;
      _batteryLevel = null;
    });

    try {
      await _ble.disconnect();

      final password = await _supabase.getUnitPairingCode(rawName);
      if (password == null || password.isEmpty) {
        throw Exception('Пароль устройства не найден в базе.');
      }

      setState(() => _scanMessage = 'Подключение к устройству...');
      await _ble.connectToDevice(macAddress);

      setState(() => _scanMessage = 'Отправка команды... ${password}99');
      final command = '${password}99';
      await _ble.writeCommand(command);

      setState(() {
        _isConnecting = false;
        _scanMessage = 'Устройство готово к регистрации. Ожидание данных ответа...';
        _connectedDeviceName = rawName;
        _connectedDeviceMac = macAddress;
      });
    } catch (e) {
      await _ble.disconnect();
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isConnecting = false;
        _scanMessage = 'Ошибка: $msg';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Scanner'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Выберите устройство для регистрации:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_scanMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _scanMessage,
                    style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(child: _buildList()),
              const SizedBox(height: 20),
              if (_isScanning && _filteredResults.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (!_savedToDb && !_isScanning) ...[
                ElevatedButton(
                  onPressed: _startScan,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: const Text('Повторить сканирование'),
                ),
                const SizedBox(height: 16),
              ],
              if (_isConnecting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_connectedDeviceName != null) ...[
                ElevatedButton(
                  onPressed: () =>
                      _navigateToRegistration(_connectedDeviceName, _connectedDeviceMac, _batteryLevel),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Зарегистрироваться'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_savedToDb) {
      if (_dbItems.isEmpty) {
        return const Center(
          child: Text('В базе пока нет устройств',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        );
      }
      return ListView.builder(
        itemCount: _dbItems.length,
        itemBuilder: (_, index) {
          final item = _dbItems[index];
          final rawName = item['name']?.toString() ?? '';
          final decoded = DecoderService.decodeInt(rawName);
          final displayName = decoded != 0 ? decoded.toString() : rawName;

          final isSelected = rawName == _connectedDeviceName;

          return Card(
            color: isSelected ? Colors.blue.shade50 : null,
            shape: isSelected
                ? RoundedRectangleBorder(
                    side: BorderSide(color: Colors.blue.shade400, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              selected: isSelected,
              onTap: () => _connectAndPrepare(
                  rawName, item['macadress']?.toString() ?? ''),
              leading: const Icon(Icons.bluetooth),
              title: Text(displayName),
              subtitle: Text(item['macadress']?.toString() ?? ''),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: Colors.blue.shade700)
                  : Text('#${item['id']}',
                      style: const TextStyle(color: Colors.grey)),
            ),
          );
        },
      );
    }

    if (_filteredResults.isEmpty) {
      if (_isScanning) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Поиск устройств...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return const Center(
        child: Text(
          'Устройства не найдены',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredResults.length,
      itemBuilder: (_, index) {
        final result = _filteredResults[index];
        final rawName = result.device.name.isNotEmpty
            ? result.device.name
            : result.advertisementData.localName.isNotEmpty
                ? result.advertisementData.localName
                : 'Unknown device';

        final decoded = DecoderService.decodeInt(rawName);
        final displayName = decoded != 0 ? 'Смайлик №$decoded' : rawName;

        final isSelected = rawName == _connectedDeviceName;

        return Card(
          color: isSelected ? Colors.blue.shade50 : null,
          shape: isSelected
              ? RoundedRectangleBorder(
                  side: BorderSide(color: Colors.blue.shade400, width: 2),
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            selected: isSelected,
            onTap: () => _connectAndPrepare(rawName, result.device.id.id),
            leading: const Icon(Icons.bluetooth),
            title: Text(displayName),
            subtitle: Text(result.device.id.id),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Colors.blue.shade700)
                : const Icon(Icons.arrow_forward_ios),
          ),
        );
      },
    );
  }
}

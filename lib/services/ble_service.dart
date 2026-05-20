import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  final Map<String, ScanResult> _scanResults = {};
  StreamSubscription<List<ScanResult>>? _subscription;

  /// Called whenever new results arrive during scan.
  ValueChanged<Map<String, ScanResult>>? onResults;

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  /// Starts a BLE scan for [duration].
  /// Returns an error message string, or null on success.
  Future<String?> startScan({Duration duration = const Duration(seconds: 5)}) async {
    final granted = await requestPermissions();
    if (!granted) return 'Нужны разрешения Bluetooth и местоположения';

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      if (Platform.isAndroid) await FlutterBluePlus.turnOn();
      await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(const Duration(seconds: 5), onTimeout: () => BluetoothAdapterState.off);
      final stateNow = await FlutterBluePlus.adapterState.first;
      if (stateNow != BluetoothAdapterState.on) {
        return 'Bluetooth выключен. Включите Bluetooth.';
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _scanResults.clear();

    _subscription?.cancel();
    _subscription = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        _scanResults[r.device.id.id] = r;
      }
      onResults?.call(Map.unmodifiable(_scanResults));
    });

    try {
      await FlutterBluePlus.startScan(timeout: duration);
      // Wait for scan to complete
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
    } catch (e) {
      return 'Ошибка сканирования: $e';
    }

    return null; // success
  }

  List<ScanResult> get allResults => _scanResults.values.toList();

  BluetoothDevice? connectedDevice;
  StreamSubscription<List<int>>? _valueSubscription;
  final _receivedDataController = StreamController<String>.broadcast();
  Stream<String> get receivedDataStream => _receivedDataController.stream;

  Future<void> connectToDevice(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await device.connect();
    connectedDevice = device;
    // Даем соединению устояться (MTU, параметры связи) перед открытием сервисов
    await Future.delayed(const Duration(milliseconds: 500));

    // Настраиваем подписку на уведомления от устройства LYS
    try {
      List<BluetoothService> services = await device.discoverServices();
      const targetUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() == targetUuid.toLowerCase()) {
            if (characteristic.properties.notify) {
              print('Найдена целевая характеристика для уведомлений LYS: $targetUuid');
              await characteristic.setNotifyValue(true);
              _valueSubscription?.cancel();
              _valueSubscription = characteristic.lastValueStream.listen((value) {
                final response = String.fromCharCodes(value).trim();
                print('Получено уведомление от устройства LYS: $response');
                _receivedDataController.add(response);
              });
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка при подписке на уведомления: $e');
    }
  }

  Future<void> writeCommand(String command) async {
    if (connectedDevice == null) throw Exception('Устройство не подключено');
    
    // Получаем список сервисов устройства
    List<BluetoothService> services = await connectedDevice!.discoverServices();
    
    print('--- НАЧАЛО ПОИСКА ХАРАКТЕРИСТИК ---');
    for (var service in services) {
      print('Сервис: ${service.uuid}');
      for (var characteristic in service.characteristics) {
        print('  Характеристика: ${characteristic.uuid}, write: ${characteristic.properties.write}, writeWithoutResponse: ${characteristic.properties.writeWithoutResponse}');
      }
    }
    print('--- КОНЕЦ ПОИСКА ХАРАКТЕРИСТИК ---');

    // 1. Сначала ищем нашу целевую характеристику по UUID
    const targetUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString().toLowerCase() == targetUuid.toLowerCase()) {
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            print('Найдена целевая характеристика LYS: $targetUuid. Выполняем запись...');
            await characteristic.write(command.codeUnits, withoutResponse: characteristic.properties.writeWithoutResponse);
            print('Запись команды "$command" успешно выполнена.');
            return;
          }
        }
      }
    }

    // 2. Если целевая характеристика не найдена, используем первую попавшуюся с правами на запись (резервный вариант)
    print('ВНИМАНИЕ: Целевая характеристика $targetUuid не найдена или не имеет прав на запись. Поиск первой доступной...');
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
          try {
            print('Запись в резервную характеристику: ${characteristic.uuid}');
            await characteristic.write(command.codeUnits, withoutResponse: characteristic.properties.writeWithoutResponse);
            return;
          } catch (e) {
            print('Ошибка записи в характеристику: $e');
          }
        }
      }
    }
    throw Exception('Не найдена характеристика с правом записи.');
  }

  Future<void> disconnect() async {
    _valueSubscription?.cancel();
    _valueSubscription = null;
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      connectedDevice = null;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _valueSubscription?.cancel();
    _receivedDataController.close();
    disconnect();
  }
}

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/decoder_service.dart';
import 'bluetooth_scan_screen.dart';
import 'welcome_screen.dart';

class MyDevicesScreen extends StatefulWidget {
  const MyDevicesScreen({super.key});

  @override
  State<MyDevicesScreen> createState() => _MyDevicesScreenState();
}

class _MyDevicesScreenState extends State<MyDevicesScreen> {
  final _db = DatabaseService();
  List<Map<String, dynamic>> _myDevices = [];
  List<Map<String, dynamic>> _metDevices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    await _db.init();
    final list = await _db.loadMyDevices();
    final metList = await _db.loadMetDevices();
    setState(() {
      _myDevices = list;
      _metDevices = metList;
      _isLoading = false;
    });
  }

  Future<void> _deleteDevice(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить устройство?'),
        content: Text('Вы действительно хотите отменить привязку для устройства "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteMyDevice(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Привязка к устройству "$name" удалена'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadDevices();
    }
  }

  Future<void> _deleteMetDevice(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить встреченное устройство?'),
        content: Text('Вы действительно хотите удалить информацию о встреченном устройстве "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteMetDevice(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Встреченное устройство "$name" удалено'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Мои Смайлики',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadDevices,
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
          elevation: 4,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3.0,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.sentiment_very_satisfied),
                text: 'Мои смайлики',
              ),
              Tab(
                icon: Icon(Icons.people_outline),
                text: 'Встреченные',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _myDevices.isEmpty
                      ? _buildEmptyState()
                      : _buildDevicesList(),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _metDevices.isEmpty
                      ? _buildMetEmptyState()
                      : _buildMetDevicesList(),
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return _myDevices.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BluetoothScanScreen(autoStartScan: true),
                        ),
                      ).then((_) => _loadDevices());
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить устройство'),
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    elevation: 4,
                  )
                : const SizedBox.shrink();
          }
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_searching,
                size: 80,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Нет привязанных устройств',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Привяжите свое первое Bluetooth устройство, чтобы контролировать и просматривать его статус.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BluetoothScanScreen(autoStartScan: true),
                  ),
                ).then((_) => _loadDevices());
              },
              icon: const Icon(Icons.add),
              label: const Text('Привязать устройство'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 80,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Никого не встретили',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'При сканировании Bluetooth другие смайлики, привязанные к чужим аккаунтам, будут автоматически сохраняться в эту вкладку.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BluetoothScanScreen(autoStartScan: true),
                  ),
                ).then((_) => _loadDevices());
              },
              icon: const Icon(Icons.search),
              label: const Text('Запустить сканирование'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryIndicator(int battery) {
    final Color batteryColor;
    final IconData batteryIcon;
    if (battery >= 60) {
      batteryColor = Colors.green.shade600;
      batteryIcon = Icons.battery_full;
    } else if (battery >= 20) {
      batteryColor = Colors.orange.shade600;
      batteryIcon = Icons.battery_3_bar;
    } else {
      batteryColor = Colors.red.shade600;
      batteryIcon = Icons.battery_alert;
    }

    return Row(
      children: [
        Icon(batteryIcon, size: 16, color: batteryColor),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: battery / 100.0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$battery%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: batteryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myDevices.length,
      itemBuilder: (context, index) {
        final device = _myDevices[index];
        final id = device['id'] as int;
        final rawName = device['name']?.toString() ?? 'Unknown';
        final mac = device['macadress']?.toString() ?? 'N/A';
        final battery = device['battery'] as int?;

        final decoded = DecoderService.decodeInt(rawName);
        final displayName = decoded != 0 ? 'Смайлик №$decoded' : rawName;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.blue.shade50.withOpacity(0.2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bluetooth_connected,
                      color: Colors.blue.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (decoded != 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Код: $rawName',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.dock, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              mac,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        if (battery != null) ...[
                          const SizedBox(height: 8),
                          _buildBatteryIndicator(battery),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    onPressed: () => _deleteDevice(id, displayName),
                    tooltip: 'Удалить привязку',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetDevicesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _metDevices.length,
      itemBuilder: (context, index) {
        final device = _metDevices[index];
        final id = device['id'] as int;
        final rawName = device['name']?.toString() ?? 'Unknown';
        final mac = device['mac']?.toString() ?? 'N/A';
        final ownerId = device['owner_id']?.toString() ?? 'N/A';

        final decoded = DecoderService.decodeInt(rawName);
        final displayName = decoded != 0 ? 'Смайлик №$decoded' : rawName;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.green.shade50.withOpacity(0.15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (decoded != 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Код: $rawName',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.dock, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              mac,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Владелец: $ownerId',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    onPressed: () => _deleteMetDevice(id, displayName),
                    tooltip: 'Удалить встреченное устройство',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

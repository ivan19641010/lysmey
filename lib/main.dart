import 'package:flutter/material.dart';

import 'screens/welcome_screen.dart';
import 'screens/my_devices_screen.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final db = DatabaseService();
  await db.init();
  final myDevices = await db.loadMyDevices();
  
  final Widget initialScreen = myDevices.isNotEmpty 
      ? const MyDevicesScreen() 
      : const WelcomeScreen();

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: initialScreen,
    );
  }
}

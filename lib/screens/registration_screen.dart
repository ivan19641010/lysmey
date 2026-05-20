import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/supabase_service.dart';
import 'my_devices_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String? deviceName;
  final String? macAddress;
  final String? batteryLevel;
  const RegistrationScreen({super.key, this.deviceName, this.macAddress, this.batteryLevel});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = SupabaseService();

  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() => _statusMessage = 'Имя обязательно для регистрации.');
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      setState(() => _statusMessage = 'Email и пароль обязательны.');
      return;
    }

    if (widget.deviceName == null) {
      setState(() => _statusMessage = 'Ошибка: устройство не выбрано.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // 1. Проверяем, не привязано ли устройство
      final existingAccountId = await _supabase.getUnitAccountId(widget.deviceName!);
      if (existingAccountId != null) {
        setState(() => _statusMessage = 'Это устройство уже привязано.');
        return;
      }

      // 2. Создаем аккаунт
      final userId = await _supabase.signUpUser(email: email, password: password, name: name);
      
      // 3. Привязываем устройство к новому аккаунту
      await _supabase.updateUnitAccountId(widget.deviceName!, userId);

      // 4. Сохраняем в локальную базу данных в таблицу mydevice
      final db = DatabaseService();
      await db.init();
      final batteryVal = widget.batteryLevel != null ? int.tryParse(widget.batteryLevel!) : null;
      await db.saveMyDevice(widget.deviceName!, widget.macAddress ?? '', battery: batteryVal);

      setState(() => _statusMessage = 'Регистрация прошла успешно. Устройство привязано.');

      // Переход на экран привязанных устройств после успешного завершения
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MyDevicesScreen()),
            (route) => false,
          );
        }
      });
    } catch (e) {
      // Убираем слово Exception из сообщения, если оно там есть
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _statusMessage = 'Ошибка: $msg');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация пользователя'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.deviceName != null) ...[
                Text(
                  'Устройство: ${widget.deviceName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Зарегистрироваться'),
              ),
              const SizedBox(height: 24),
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.startsWith('Ошибка') ? Colors.red : Colors.green.shade700,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

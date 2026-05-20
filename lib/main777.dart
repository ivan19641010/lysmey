import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Регистрация пользователя',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RegistrationScreen(),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _statusMessage = '';

  static const _supabaseUrl =
      'https://wsttmotnooiyhcwpgmmg.supabase.co';
  static const _anonKey =
      'sb_publishable_iGCA_0b0CVii90njs4BKQg__18aPuzQ';
  static const _defaultRoleName = 'user';

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() {
        _statusMessage = 'Имя обязательно для регистрации.';
      });
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'Email и пароль обязательны.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final userId =
          await _signUpUser(email: email, password: password, name: name);
      final roleId = await _fetchRoleId(_defaultRoleName);

      if (roleId == null) {
        throw Exception('Роль "$_defaultRoleName" не найдена в таблице roles.');
      }

      await _createAccount(id: userId, name: name, roleId: roleId);

      setState(() {
        _statusMessage = 'Регистрация прошла успешно. Пользователь создан.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Ошибка регистрации: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    final uri = Uri.parse('$_supabaseUrl/auth/v1/signup');
    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json')
      ..set('apikey', _anonKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $_anonKey');

    final body = jsonEncode({
      'email': email,
      'password': password,
      'options': {
        'data': {
          'name': name,
        },
      },
    });
    request.add(utf8.encode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Ошибка signup: $responseBody');
    }

    final data = jsonDecode(responseBody);
    if (data is Map<String, dynamic> && data['id'] is String) {
      return data['id'] as String;
    }
    throw Exception('Не удалось получить идентификатор пользователя.');
  }

  Future<int?> _fetchRoleId(String roleName) async {
    final uri =
        Uri.parse('$_supabaseUrl/rest/v1/roles?select=id&name=eq.$roleName');
    final client = HttpClient();
    final request = await client.getUrl(uri);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set('apikey', _anonKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $_anonKey');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200) {
      throw Exception('Ошибка роли: $responseBody');
    }

    final data = jsonDecode(responseBody);
    if (data is List && data.isNotEmpty && data.first['id'] != null) {
      return data.first['id'] as int;
    }
    return null;
  }

  Future<void> _createAccount({
    required String id,
    required String name,
    required int roleId,
  }) async {
    final uri = Uri.parse('$_supabaseUrl/rest/v1/accounts');
    final client = HttpClient();
    final request = await client.postUrl(uri);
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json')
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set('apikey', _anonKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $_anonKey')
      ..set('Prefer', 'return=representation');

    final body = jsonEncode({
      'id': id,
      'name': name,
      'role_id': roleId,
    });
    request.add(utf8.encode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Ошибка создания аккаунта: $responseBody');
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
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Зарегистрироваться'),
              ),
              const SizedBox(height: 24),
              if (_statusMessage.isNotEmpty)
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.startsWith('Ошибка')
                        ? Colors.red
                        : Colors.green.shade700,
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

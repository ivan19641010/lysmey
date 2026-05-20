import 'dart:convert';
import 'dart:io';

class SupabaseService {
  //greg
  //static const _supabaseUrl = 'https://yiayeycirlvngfpsnqkr.supabase.co';
  //static const _anonKey = 'sb_publishable_DIw7IIYnmpdo5tJ2n4Z-_A_gKLbA7Vw';
  //my
  static const _supabaseUrl = 'https://wsttmotnooiyhcwpgmmg.supabase.co';
  static const _anonKey = 'sb_publishable_iGCA_0b0CVii90njs4BKQg__18aPuzQ';

  Future<String?> getUnitAccountId(String btname) async {
    final uri = Uri.parse(
        '$_supabaseUrl/rest/v1/units?btname=eq.$btname&select=account_id');
    print('GET request to: $uri');

    final client = HttpClient();
    final request = await client.getUrl(uri);
    request.headers
      ..set('apikey', _anonKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $_anonKey');
    final response = await request.close();
    print('Response status: ${response.statusCode}');

    final responseBody = await response.transform(utf8.decoder).join();
    print('Response body: $responseBody');
    client.close();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody) as List;
      if (data.isNotEmpty) {
        return data[0]['account_id'] as String?;
      }
      throw Exception('Устройство с таким именем не найдено в системе.');
    }
    throw Exception('Ошибка при проверке устройства: ${response.statusCode}');
  }

  Future<String?> getUnitPairingCode(String btname) async {
    final uri = Uri.parse(
        '$_supabaseUrl/rest/v1/units?btname=eq.$btname&select=pairing_code');
    final client = HttpClient();
    final request = await client.getUrl(uri);
    request.headers
      ..set('apikey', _anonKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $_anonKey');
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody) as List;
      if (data.isNotEmpty) {
        return data[0]['pairing_code']?.toString();
      }
      throw Exception('Устройство с таким именем не найдено в системе.');
    }
    throw Exception(
        'Ошибка при получении пароля устройства: ${response.statusCode}');
  }

  Future<void> updateUnitAccountId(String btname, String accountId) async {
    final uri = Uri.parse('$_supabaseUrl/rest/v1/units?btname=eq.$btname');
    print('PATCH request to: $uri');

    final client = HttpClient();
    final request = await client.patchUrl(uri);
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json')
      ..set('apikey', _anonKey)
      ..set(HttpHeaders.authorizationHeader, 'Bearer $_anonKey')
      ..set('Prefer', 'return=minimal');

    final body = jsonEncode({'account_id': accountId});
    print('PATCH body: $body');
    request.add(utf8.encode(body));

    final response = await request.close();
    print('Response status: ${response.statusCode}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      final responseBody = await response.transform(utf8.decoder).join();
      print('Response error body: $responseBody');
      client.close();
      throw Exception('Не удалось привязать устройство: $responseBody');
    }
    client.close();
  }

  /// Registers a new user in Supabase Auth.
  /// Returns the user ID on success, throws [Exception] on failure.
  Future<String> signUpUser({
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
      'data': {'name': name},
    });
    request.add(utf8.encode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Ошибка signup: $responseBody');
    }

    final data = jsonDecode(responseBody);
    if (data is Map<String, dynamic>) {
      final user = data['user'] as Map<String, dynamic>?;
      if (user != null && user['id'] is String) {
        return user['id'] as String;
      }
      if (data['id'] is String) return data['id'] as String;
    }
    throw Exception('Не удалось получить идентификатор пользователя.');
  }
}

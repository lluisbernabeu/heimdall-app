import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente API de Heimdall backend.
class ApiClient {
  static const String base = 'https://heimdall.lluis154.uk';

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('heimdall_token');
  }

  static Future<void> setToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('heimdall_token', token);
  }

  static Future<void> clearToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('heimdall_token');
  }

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'User-Agent': 'HeimdallApp/1.0 (Android)',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<dynamic> _req(String method, String path,
      {Object? body, bool auth = true}) async {
    final token = auth ? await getToken() : null;
    final uri = Uri.parse('$base$path');
    late http.Response res;
    try {
      if (method == 'GET') {
        res = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 30));
      } else if (method == 'POST') {
        res = await http.post(uri, headers: _headers(token),
            body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 30));
      } else {
        throw Exception('Método no soportado: $method');
      }
    } catch (e) {
      throw Exception('No se pudo conectar con Heimdall: $e');
    }
    if (res.statusCode == 401) {
      await clearToken();
      throw AuthExpiredException();
    }
    if (res.statusCode >= 400) {
      String detail = 'Error ${res.statusCode}';
      try {
        final d = jsonDecode(res.body);
        if (d is Map && d['detail'] != null) detail = d['detail'].toString();
      } catch (_) {}
      throw ApiException(detail);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> get(String path) => _req('GET', path);
  static Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _req('POST', path, body: body, auth: auth);
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class AuthExpiredException implements Exception {}

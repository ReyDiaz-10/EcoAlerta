import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AdminService {
  static String? _accessToken;
  static String? _refreshToken;

  static String? get accessToken => _accessToken;
  static bool get isLoggedIn => _accessToken != null;

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            ApiConfig.endpoint('/admin/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
      final decoded = _decode(response);
      if (response.statusCode == 200 && decoded['access_token'] != null) {
        _accessToken = decoded['access_token'] as String;
        _refreshToken = decoded['refresh_token'] as String?;
        return {'success': true};
      }
      return {'success': false, 'error': decoded['detail'] ?? 'No se pudo iniciar sesión'};
    } on TimeoutException {
      return {'success': false, 'error': 'El servidor tardó demasiado en responder'};
    } catch (_) {
      return {'success': false, 'error': 'No fue posible conectar con EcoAlerta'};
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<bool> _refresh() async {
    if (_refreshToken == null) return false;
    final response = await http
        .post(
          ApiConfig.endpoint('/admin/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': _refreshToken}),
        )
        .timeout(const Duration(seconds: 20));
    final decoded = _decode(response);
    if (response.statusCode != 200 || decoded['access_token'] == null) return false;
    _accessToken = decoded['access_token'] as String;
    _refreshToken = decoded['refresh_token'] as String?;
    return true;
  }

  static Future<http.Response?> _authorizedGet(String path) async {
    if (_accessToken == null) return null;
    http.Response response = await http
        .get(ApiConfig.endpoint(path), headers: {'Authorization': 'Bearer $_accessToken'})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 401 && await _refresh()) {
      response = await http
          .get(ApiConfig.endpoint(path), headers: {'Authorization': 'Bearer $_accessToken'})
          .timeout(const Duration(seconds: 25));
    }
    return response;
  }

  static void logout() {
    final token = _refreshToken;
    _accessToken = null;
    _refreshToken = null;
    if (token != null) {
      http.post(
        ApiConfig.endpoint('/admin/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': token}),
      ).timeout(const Duration(seconds: 10)).catchError((_) => http.Response('', 0));
    }
  }

  static Future<Map<String, dynamic>> fetchMetrics() async {
    try {
      final response = await _authorizedGet('/admin/metrics');
      if (response == null) return {'success': false, 'error': 'No autorizado'};
      final decoded = _decode(response);
      if (response.statusCode == 200 && decoded['metrics'] != null) {
        return {'success': true, 'metrics': decoded['metrics']};
      }
      return {'success': false, 'error': decoded['detail'] ?? 'Error al obtener métricas'};
    } catch (_) {
      return {'success': false, 'error': 'No fue posible cargar las métricas'};
    }
  }

  static Future<Map<String, dynamic>> fetchReports() async {
    try {
      final response = await _authorizedGet('/reportes');
      if (response == null) return {'success': false, 'error': 'No autorizado'};
      final decoded = _decode(response);
      if (response.statusCode == 200 && decoded['reportes'] is List) {
        return {'success': true, 'reports': decoded['reportes']};
      }
      return {'success': false, 'error': decoded['detail'] ?? 'No se pudieron cargar los reportes'};
    } catch (_) {
      return {'success': false, 'error': 'No fue posible cargar los reportes'};
    }
  }
}

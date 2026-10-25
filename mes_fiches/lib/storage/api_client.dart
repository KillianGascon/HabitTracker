import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sync.dart';
import 'api_config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message);

  /// Code HTTP, ou 0 si l'API n'a pas pu être jointe.
  final int status;
  final String message;

  bool get unauthorized => status == 401;

  @override
  String toString() => status == 0 ? message : '$message ($status)';
}

/// Appels à l'API (voir api/README.md et /docs).
class ApiClient {
  ApiClient(this.config, {this.cfClientSecret = '', this.token, http.Client? client})
      : _http = client ?? http.Client();

  final ApiConfig config;
  final String cfClientSecret;
  String? token;
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = config.baseUrl.endsWith('/') ? config.baseUrl.substring(0, config.baseUrl.length - 1) : config.baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
        if (config.cfClientId.isNotEmpty) 'CF-Access-Client-Id': config.cfClientId,
        if (cfClientSecret.isNotEmpty) 'CF-Access-Client-Secret': cfClientSecret,
      };

  Future<Map<String, dynamic>> _send(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    final req = http.Request(method, _uri(path, query))..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } catch (e) {
      throw ApiException(0, 'API injoignable : $e');
    }
    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
    }
    String message = 'Erreur de l’API';
    try {
      message = (jsonDecode(text) as Map<String, dynamic>)['error'] as String? ?? message;
    } catch (_) {
      // Réponse non JSON : typiquement la page de refus de Cloudflare Access.
      if (res.statusCode == 403) message = 'Refusé par Cloudflare Access (identifiants de service ?)';
    }
    throw ApiException(res.statusCode, message);
  }

  Future<bool> health() async => (await _send('GET', '/health'))['status'] == 'ok';

  /// Échange le code d'association contre un jeton d'appareil.
  Future<String> pair(String code) async {
    final r = await _send('POST', '/v1/devices/pair', body: {'code': code, 'name': config.deviceName});
    return token = r['token'] as String;
  }

  Future<void> push(PendingChanges changes) => _send('POST', '/v1/sync', body: changes.toRequest());

  Future<RemoteChanges> pull(int since) async =>
      RemoteChanges.fromJson(await _send('GET', '/v1/sync', query: {'since': '$since'}));

  void close() => _http.close();
}

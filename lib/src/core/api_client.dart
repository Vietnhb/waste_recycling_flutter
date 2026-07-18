import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'json_helpers.dart';

class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;

  Uri _uri(String endpoint, [Map<String, String?> query = const {}]) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$base$path');
    final params = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) params[entry.key] = value;
    }
    return uri.replace(queryParameters: {...uri.queryParameters, ...params});
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(
    String endpoint, [
    Map<String, String?> query = const {},
  ]) async {
    final response = await http.get(_uri(endpoint, query), headers: _headers);
    return _decode(response);
  }

  Future<dynamic> post(String endpoint, [Object? body]) async {
    final response = await http.post(
      _uri(endpoint),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> postImage(
    String endpoint, {
    required Uint8List bytes,
    required String filename,
    Map<String, String> fields = const {},
    Map<String, String> headers = const {},
  }) async {
    final request = http.MultipartRequest('POST', _uri(endpoint));
    request.headers['Accept'] = 'application/json';
    if (token != null && token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers.addAll(headers);
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
    final streamed = await request.send();
    return _decode(await http.Response.fromStream(streamed));
  }

  Future<dynamic> put(
    String endpoint, [
    Object? body,
    Map<String, String?> query = const {},
  ]) async {
    final response = await http.put(
      _uri(endpoint, query),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> delete(String endpoint) async {
    final response = await http.delete(_uri(endpoint), headers: _headers);
    _decode(response);
  }

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    dynamic body;
    if (text.isNotEmpty) {
      try {
        body = jsonDecode(text);
      } catch (_) {
        body = text;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map
          ? asString(body['message'], 'Có lỗi xảy ra từ server')
          : (text.isEmpty ? 'HTTP ${response.statusCode}' : text);
      final code = body is Map ? asString(body['code']).trim() : '';
      final retryable = body is Map && body['retryable'] == true;
      throw ApiException(
        message,
        response.statusCode,
        code.isEmpty ? null : code,
        retryable,
      );
    }
    return body;
  }
}

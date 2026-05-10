import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _wsBaseUrlOverride = String.fromEnvironment(
    'WS_BASE_URL',
  );

  static String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return 'http://$defaultHost:8080';
  }

  static String get wsBaseUrl {
    if (_wsBaseUrlOverride.isNotEmpty) return _wsBaseUrlOverride;
    return 'ws://$defaultHost:8080';
  }

  static String get defaultHost {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return '127.0.0.1';
  }

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadPhoto(
    String path,
    File imageFile, {
    String? label,
    String? token,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (label != null && label.isNotEmpty) {
      request.fields['label'] = label;
    }
    request.files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}

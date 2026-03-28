import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Server {
  static const _storage = FlutterSecureStorage();
  static const _urlKey = 'server_url';

  String? _serverUrl;

  // Loads the saved server URL from device storage on app startup
  Future<void> loadServerUrl() async {
    _serverUrl = await _storage.read(key: _urlKey);
  }

  // Getter for server URL
  String? getServerUrl() {
    return _serverUrl;
  }

  // Saves a new server URL and removes trailing slashes for consistency
  Future<void> setServerUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    _serverUrl = cleanUrl;
    await _storage.write(key: _urlKey, value: _serverUrl);
  }

  // Returns true if a server URL has been saved
  bool isServerConfigured() {
    return _serverUrl != null && _serverUrl!.isNotEmpty;
  }

  // Checks if the app can establish a connection to the server
  Future<bool> testServerConnection() async {
    if (!isServerConfigured()) return false;
    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/api/auth/login/'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 405;
    } catch (e) {
      return false;
    }
  }

  // Helper method that builds the headers for every request
  Map<String, String> _buildHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  // Sends a GET request to the given endpoint
  Future<Map<String, dynamic>> sendGet(String endpoint, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    final response = await http.get(url, headers: _buildHeaders(token: token));
    return _parseResponse(response);
  }

  // Sends a POST request with a JSON body to the given endpoint
  Future<Map<String, dynamic>> sendPost(String endpoint, Map<String, dynamic> body, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    final response = await http.post(url, headers: _buildHeaders(token: token), body: jsonEncode(body));
    return _parseResponse(response);
  }

  // Sends a PUT request with a JSON body to the given endpoint
  Future<Map<String, dynamic>> sendPut(String endpoint, Map<String, dynamic> body, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    final response = await http.put(url, headers: _buildHeaders(token: token), body: jsonEncode(body));
    return _parseResponse(response);
  }

  // Sends a PATCH request with a JSON body to the given endpoint
  Future<Map<String, dynamic>> sendPatch(String endpoint, Map<String, dynamic> body, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    final response = await http.patch(url, headers: _buildHeaders(token: token), body: jsonEncode(body));
    return _parseResponse(response);
  }

  // Sends a DELETE request to the given endpoint
  Future<void> sendDelete(String endpoint, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    final response = await http.delete(url, headers: _buildHeaders(token: token));
    if (response.statusCode >= 400) {
      throw ServerException(response.statusCode, response.body);
    }
  }

  // Parses the HTTP response and throws ServerException for invalid HTTP responses
  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode >= 400) {
      throw ServerException(response.statusCode, response.body);
    }
    return jsonDecode(response.body);
  }
}

class ServerException implements Exception {
  final int statusCode;
  final String body;

  const ServerException(this.statusCode, this.body);

  @override
  String toString() => 'ServerException($statusCode): $body';
}
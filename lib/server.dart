import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Server {
  final _log = Logger('Server');
  static const _storage = FlutterSecureStorage();
  static const _urlKey = 'server_url';
  static const _timeout = Duration(seconds: 3);

  String? _serverUrl;

  // Loads the saved server URL from device storage on app startup
  Future<void> loadServerUrl() async {
    _serverUrl = await _storage.read(key: _urlKey);
  }

  // Getter for server URL
  String? getServerUrl() {
    return _serverUrl;
  }

  // Setter for server URL (also removes trailing slashes)
  void setServerUrl(String url) {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    _serverUrl = cleanUrl;
  }

  // Saves a new server URL to storage
  Future<void> saveServerUrl(String url) async {
    setServerUrl(url);
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
          .timeout(_timeout);
      return response.statusCode == 405;
    } catch (e) {
      _log.warning(e);
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
    _log.fine('GET $endpoint');

    final response = await http
        .get(url, headers: _buildHeaders(token: token))
        .timeout(_timeout);
    return _parseResponse(response);
  }

  // Sends a GET request to the given endpoint, expecting a JSON array response
  Future<List<dynamic>> sendGetList(String endpoint, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    _log.fine('GET $endpoint');

    final response = await http
        .get(url, headers: _buildHeaders(token: token))
        .timeout(_timeout);

    if (response.statusCode >= 400) {
      _log.warning('HTTP ${response.statusCode} on ${response.request?.url}');
      throw ServerException(response.statusCode, response.body);
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  // Sends a POST request with a JSON body to the given endpoint
  Future<Map<String, dynamic>> sendPost(String endpoint, Map<String, dynamic> body, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    _log.fine('POST $endpoint');

    final response = await http
        .post(url, headers: _buildHeaders(token: token), body: jsonEncode(body))
        .timeout(_timeout);
    return _parseResponse(response);
  }

  // Sends a PUT request with a JSON body to the given endpoint
  Future<Map<String, dynamic>> sendPut(String endpoint, Map<String, dynamic> body, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    _log.fine('PUT $endpoint');

    final response = await http
        .put(url, headers: _buildHeaders(token: token), body: jsonEncode(body))
        .timeout(_timeout);
    return _parseResponse(response);
  }

  // Sends a PATCH request with a JSON body to the given endpoint
  Future<Map<String, dynamic>> sendPatch(String endpoint, Map<String, dynamic> body, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    _log.fine('PATCH $endpoint');

    final response = await http
        .patch(url, headers: _buildHeaders(token: token), body: jsonEncode(body))
        .timeout(_timeout);
    return _parseResponse(response);
  }

  // Sends a DELETE request to the given endpoint
  Future<void> sendDelete(String endpoint, {String? token}) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    _log.fine('DELETE $endpoint');

    final response = await http
        .delete(url, headers: _buildHeaders(token: token))
        .timeout(_timeout);
    if (response.statusCode >= 400) {
      throw ServerException(response.statusCode, response.body);
    }
  }

  // Sends a multipart POST request with a file to the given endpoint
  Future<Map<String, dynamic>> sendMultipart(
    String endpoint,
    String fieldName,
    List<int> fileBytes,
    String filename, {
    String? token,
  }) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    _log.fine('MULTIPART POST $endpoint');

    final request = http.MultipartRequest('POST', url);
    if (token != null) request.headers['Authorization'] = 'Token $token';
    request.files.add(http.MultipartFile.fromBytes(
      fieldName,
      fileBytes,
      filename: filename,
    ));

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _parseResponse(response);
  }

  // Sends a multipart PATCH request with a file to the given endpoint
  Future<Map<String, dynamic>> sendMultipartPatch(
    String endpoint,
    String fieldName,
    List<int> fileBytes,
    String filename, {
    String? token,
  }) async {
    final url = Uri.parse('$_serverUrl$endpoint');
    _log.fine('MULTIPART PATCH $endpoint');

    final request = http.MultipartRequest('PATCH', url);
    if (token != null) request.headers['Authorization'] = 'Token $token';
    request.files.add(http.MultipartFile.fromBytes(
      fieldName,
      fileBytes,
      filename: filename,
    ));

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _parseResponse(response);
  }

  // Parses the HTTP response and throws ServerException for invalid HTTP responses
  Map<String, dynamic> _parseResponse(http.Response response) {
    if (response.statusCode >= 400) {
      _log.warning('HTTP ${response.statusCode} on ${response.request?.url}');
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
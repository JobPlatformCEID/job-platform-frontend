import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const _storage = FlutterSecureStorage();

  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };
  }

  static Future<http.Response> register(Map<String, dynamic> body) async {
    return await http.post(
      Uri.parse('$baseUrl/api/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> login(String username, String password) async {
    return await http.post(
      Uri.parse('$baseUrl/api/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
  }

  static Future<http.Response> getCandidateProfile() async {
    return await http.get(
      Uri.parse('$baseUrl/api/candidates/me/'),
      headers: await _authHeaders(),
    );
  }

  static Future<http.Response> updateCandidateProfile(Map<String, dynamic> body) async {
    return await http.put(
      Uri.parse('$baseUrl/api/candidates/me/'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> getEmployerProfile() async {
    return await http.get(
      Uri.parse('$baseUrl/api/employers/me/'),
      headers: await _authHeaders(),
    );
  }

  static Future<http.Response> updateEmployerProfile(Map<String, dynamic> body) async {
    return await http.put(
      Uri.parse('$baseUrl/api/employers/me/'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> getJobs() async {
    return await http.get(
      Uri.parse('$baseUrl/api/jobs/'),
      headers: await _authHeaders(),
    );
  }

  static Future<http.Response> applyForJob(int id) async {
    return await http.post(
      Uri.parse('$baseUrl/api/jobs/$id/apply/'),
      headers: await _authHeaders(),
    );
  }

  static Future<http.Response> getApplications() async {
    return await http.get(
      Uri.parse('$baseUrl/api/jobs/applications/'),
      headers: await _authHeaders(),
    );
  }

  static Future<http.Response> updateApplicationStatus(int id, String status) async {
    return await http.patch(
      Uri.parse('$baseUrl/api/jobs/applications/$id/status/'),
      headers: await _authHeaders(),
      body: jsonEncode({'status': status}),
    );
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_role');
  }
}
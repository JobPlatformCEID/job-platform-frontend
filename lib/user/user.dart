import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../server/server.dart';

// User roles that someone in the platform can have: Matches django User model
enum UserRole { candidate, employer }

class User {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'auth_username';
  static const _roleKey = 'auth_role';

  final Server _server;

  String? _token;
  String? _username;
  UserRole? _role;

  User({required Server server}) : _server = server;

  // Getters
  String? getToken() {
    return _token;
  }
  String? getUsername() {
    return _username;
  }
  UserRole? getRole() {
    return _role;
  }

  // Returns true if there is a valid token saved
  bool isLoggedIn() {
    return _token != null;
  }

  /// Login: Sends credentials to the server and stores the token
  Future<void> login(String username, String password) async {
    final response = await _server.sendPost('/api/auth/login/', {
      'username': username,
      'password': password,
    });

    _token = response['token'] as String;
    _username = username;
    _role = _parseRole(response['role'] as String);

    await _saveSession();
  }

  // Register: Creates a new account on the server and then logs in
  Future<void> register(
    String username,
    String password,
    UserRole role, {
    String firstName = '',
    String lastName = '',
    String email = '',
  }) async {
    await _server.sendPost('/api/auth/register/', {
      'username': username,
      'password': password,
      'role': _roleToString(role),
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
    });

    await login(username, password);
  }

  // Logout: Clears all stored session data and resets the user state.
  Future<void> logout() async {
    _token = null;
    _username = null;
    _role = null;

    await _clearSession();
  }

  // Helper method that loads a previous session's data from storage
  Future<bool> loadSession() async {
    final savedToken = await _storage.read(key: _tokenKey);
    final savedUsername = await _storage.read(key: _usernameKey);
    final savedRole = await _storage.read(key: _roleKey);

    if (savedToken != null && savedUsername != null && savedRole != null) {
      _token = savedToken;
      _username = savedUsername;
      _role = _parseRole(savedRole);
      return true;
    }

    return false;
  }

  // Helper method that writes the current session to secure storage.
  Future<void> _saveSession() async {
    await _storage.write(key: _tokenKey, value: _token);
    await _storage.write(key: _usernameKey, value: _username);
    await _storage.write(key: _roleKey, value: _roleToString(_role!));
  }

  // Helper method that removes all session keys from secure storage.
  Future<void> _clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _roleKey);
  }

  // Helper method that converts a role string into a [UserRole] enum value
  static UserRole _parseRole(String role) {
    switch (role) {
      case 'candidate':
        return UserRole.candidate;
      case 'employer':
        return UserRole.employer;
      default:
        throw ArgumentError('Unknown role: $role');
    }
  }

  /// Helper method that converts a [UserRole] enum value into a string
  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.candidate:
        return 'candidate';
      case UserRole.employer:
        return 'employer';
    }
  }
}

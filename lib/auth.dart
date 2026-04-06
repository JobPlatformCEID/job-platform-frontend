import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'server.dart';
import 'user.dart';

// User roles that someone in the platform can have: Matches django User model
enum UserRole { candidate, employer }

class Auth {
  final _log = Logger('Auth');
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _usernameKey = 'auth_username';
  static const _roleKey = 'auth_role';
  static const _userIdKey = "auth_id";

  final Server _server;
  User? user;
  
  Auth({required Server server}) : _server = server;

  // Login: Sends credentials to the server and stores the token
  Future<void> login(String username, String password) async {
    final response = await _server.sendPost('/api/auth/login/', {
      'username': username,
      'password': password,
    });
  
    final token = response['token'] as String;
    final role = _stringToRole(response['role'] as String);
    final userId = response['id'] as int;

    user = _createUser(username, token, role, userId);
    _log.info('Logged in as $username (${_roleToString(role)})');
    await _saveSession(username, token, _roleToString(role), userId);
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

  // Log out: Removes the User reference
  Future<void> logout() async {
    _log.info('Logging out ${user?.username}');
    user = null;
    await _clearSession();
  }

  // Method that creates the right User subclass based on role
  User _createUser(String username, String token, UserRole role, int userId) {
    switch (role) {
      case UserRole.candidate:
        return Candidate(server: _server, username: username, token: token, userId: userId);
      case UserRole.employer:
        return Employer(server: _server, username: username, token: token, userId: userId);
    }
  }

  // Helper method that loads a previous session's data from storage
  Future<bool> loadSession() async {
    final savedToken = await _storage.read(key: _tokenKey);
    final savedUsername = await _storage.read(key: _usernameKey);
    final savedRole = await _storage.read(key: _roleKey);
    final savedUserId = await _storage.read(key: _userIdKey);

    if (savedToken != null && savedUsername != null && savedRole != null && savedUserId != null) {
      user = _createUser(savedUsername, savedToken, _stringToRole(savedRole), int.parse(savedUserId));
      _log.info('Session restored for $savedUsername (${_stringToRole(savedRole)})');
      return true;
    }

    _log.info('No saved session found');
    return false;
  }

  // Helper method that writes the current session to secure storage.
  Future<void> _saveSession(String username, String token, String role, int userId) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _userIdKey, value: userId.toString());
  }

  // Helper method that removes all session keys from secure storage.
  Future<void> _clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _userIdKey);
  }

  // Helper method that converts a role string into a [UserRole] enum value
  static UserRole _stringToRole(String role) {
    switch (role) {
      case 'candidate':
        return UserRole.candidate;
      case 'employer':
        return UserRole.employer;
      default:
        throw ArgumentError('Unknown role: $role');
    }
  }

  // Helper method that converts a [UserRole] enum value into a string
  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.candidate:
        return 'candidate';
      case UserRole.employer:
        return 'employer';
    }
  }
}
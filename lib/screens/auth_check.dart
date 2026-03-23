import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'cand_home.dart';
import 'emp_home.dart';
import 'login_screen.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    // read vault
    String? token = await _storage.read(key: 'auth_token');

    if (!mounted) return;

    // where to go
    if (token != null) {
      // token exists, go to Home.
      String? role = await _storage.read(key: 'user_role');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => role == 'employer' 
        ? const EmployerHomeScreen() 
        : const CandidateHomeScreen()),
      );
    } else {
      // no token ,go to Login.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
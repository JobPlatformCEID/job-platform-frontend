import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dummy_home.dart';
import 'reg_screen.dart';
import 'cand_home.dart';
import 'emp_home.dart';
import 'cand_setup.dart';
import 'emp_setup.dart';
import '../services/api_serv.dart';
import '../services/config.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
} 

class _LoginScreenState extends State<LoginScreen>{

  bool _remember = false;
  final _storage = const FlutterSecureStorage();

  final  _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;


  final String apiUrl = '${AppConfig.baseUrl}/api/auth/login/';

  Future<void> login() async{
      print(apiUrl);

    setState((){
        _isLoading = true;
    });

    try{
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type' : 'application/json'},
        body: jsonEncode({
          'username':_usernameController.text,
          'password':_passwordController.text,
        })
      );

      print('====== DJANGO RESPONSE ======');
      print(response.body);

      if(response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];
        final role = responseData['role'];

        print('Login successful! Token: $token');

        if(_remember){
          await _storage.write(key: 'auth_token', value: token);
          await _storage.write(key: 'user_role', value: role); 
          print('token saved and role saved...');
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => role == 'employer' 
          ? const EmployerHomeScreen() 
          : const CandidateHomeScreen()),
          );
        }

      } else {
        _showErrorDialog('Login failed. Please show your credentials');
      }
      } catch (e) {
        print('===Error Details===');
        print(e.toString());
        _showErrorDialog('Network error. Is your Django server running?');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }

   void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('An Error Occurred'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('Okay'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }




@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      body: Center(
        // SingleChildScrollView prevents the "Yellow/Black Striped Error" 
        // when the keyboard pops up and covers the screen
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch, // Makes button full-width
            children: [
              // Logo/Icon Placeholder
              const Icon(Icons.work_outline, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              
              // Welcome Text
              const Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Login to find your next opportunity',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),

              // Username Field
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none, // Removes the harsh black outline
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: true, // Hides the password with dots
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // remember me feature
              Row(
                children: [
                  Checkbox(
                    value: _remember,
                    activeColor: Colors.blueAccent,
                    onChanged: (bool? value) {
                      setState(() {
                        _remember = value ?? false;
                      });
                    },
                  ),
                  const Text(
                    'Remember Me',
                    style: TextStyle(color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Login Button
              ElevatedButton(
                onPressed: login, // This calls your existing working function!
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'LOGIN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(color: Colors.black54),
                  ),
                  GestureDetector(
                    onTap:(){
                      Navigator.push(context,MaterialPageRoute(builder: (context) => const RegisterScreen()),);
                    },
                    child: const Text("Create one now!",
                    style: TextStyle(color: Colors.blueAccent,fontWeight: FontWeight.bold),),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}





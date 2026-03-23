import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});


  Future<void> _logout(BuildContext context) async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'auth_token');

    if(context.mounted){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> const LoginScreen()),);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: const Center(
        child: Text('Welcome, Login Successful!.', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'screens/auth_check.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WebRTC.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Platform',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50], 
      ),
      home: const AuthCheckScreen(), 
    );
  }
}

//App opens
//    ↓
//AuthCheckScreen check for saved token)
//    ↓                    ↓
//token found          no token
//    ↓                    ↓
//HomeScreen          LoginScreen
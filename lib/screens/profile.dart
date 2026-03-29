import 'package:flutter/material.dart';
import '../server.dart';
import '../user.dart';

class ProfileScreen extends StatelessWidget {
  final Server server;
  final User user;

  const ProfileScreen({super.key, required this.server, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: const Center(child: Text('Profile screen coming soon')),
    );
  }
}
import 'package:flutter/material.dart';
import '../server.dart';
import '../user.dart';

class ViewProfileScreen extends StatelessWidget {
  final Server server;
  final User user;

  const ViewProfileScreen({super.key, required this.server, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: const Center(
        child: Text('Coming soon.'),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';

class AiInterviewsScreen extends StatelessWidget {
  final Server server;
  final Auth auth;

  const AiInterviewsScreen({
    super.key,
    required this.server,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy, size: 64),
            SizedBox(height: 16),
            Text('Coming Soon', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}

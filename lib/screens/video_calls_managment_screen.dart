import 'package:flutter/material.dart';
import '../auth.dart';
import 'call_waiting_room.dart';

class VideoCallsManagmentScreen extends StatelessWidget {
  final Auth auth;
  
  const VideoCallsManagmentScreen({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Rooms'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CallWaitingRoom(auth: auth),
              ),
            );
          },
          child: const Text('Join Test Room'),
        ),
      ),
    );
  }
}

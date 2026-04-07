// lib/screens/waiting_room.dart
import 'package:flutter/material.dart';
import '../auth.dart';

// Minimal skeleton - matches CallsScreen._joinRoom() call
class WaitingRoom extends StatefulWidget {
  final Auth auth;
  final String roomId;  

  const WaitingRoom({
    super.key,
    required this.auth,
    required this.roomId,  
  });

  @override
  State<WaitingRoom> createState() => _WaitingRoomState();
}

class _WaitingRoomState extends State<WaitingRoom> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room #${widget.roomId}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const Center(
        child: Text('Waiting room skeleton - expand later'),
      ),
    );
  }
}
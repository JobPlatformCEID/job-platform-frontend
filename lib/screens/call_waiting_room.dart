import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';

class CallWaitingRoom extends StatefulWidget {
  final Auth auth;
  
  const CallWaitingRoom({super.key, required this.auth});

  @override
  State<CallWaitingRoom> createState() => _CallWaitingRoomState();
}

class _CallWaitingRoomState extends State<CallWaitingRoom> {
  Map<String, dynamic>? roomData;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchRoomData();
  }

  Future<void> _fetchRoomData() async {
    try {
      // Use the fixed room ID (1) that we created
      // In the future, this should come from route parameters
      final response = await widget.auth.user!.server.sendGet('/api/calls/1/', token: widget.auth.user!.token);
      
      setState(() {
        roomData = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load room: $e';
        isLoading = false;
      });
    }
  }

  bool get isHost {
    if (roomData == null) return false;
    final currentUsername = widget.auth.user?.username;
    final hostUsername = roomData!['host'];
    return currentUsername == hostUsername;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading room information...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchRoomData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final String roomName = roomData!['room_name'] ?? 'Unknown Room';
    final String hostUsername = roomData!['host'] ?? 'Unknown Host';
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(roomName),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.video_call,
                  size: 64,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                roomName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Host: $hostUsername',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              if (isHost) ...[
                // Host view
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Start the call / activate room 
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Starting call...')),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You are the host. Start the call when ready.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Guest view
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Waiting for host to start the call...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please stay in this room. You will be connected automatically.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

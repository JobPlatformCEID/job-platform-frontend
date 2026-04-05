import 'package:flutter/material.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final String token;
  final String currentUsername;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.token,
    required this.currentUsername,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Video area (placeholder for now)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[900],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off,
                      size: 80,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Video feed will appear here',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Messages area
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[800],
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Messages header
                  const Row(
                    children: [
                      Icon(Icons.message, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Call Messages',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Messages list
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet...',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    _messages[index],
                                    style:
                                        const TextStyle(color: Colors.white),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),

                  // Message input
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle:
                                const TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide:
                                  const BorderSide(color: Colors.white54),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide:
                                  const BorderSide(color: Colors.white54),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide:
                                  const BorderSide(color: Colors.blue),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          if (_messageController.text.trim().isNotEmpty) {
                            setState(() {
                              _messages
                                  .add(_messageController.text.trim());
                              _messageController.clear();
                            });
                          }
                        },
                        icon: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Control buttons
          Container(
            color: Colors.grey[900],
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute/Unmute
                IconButton(
                  onPressed: () => setState(() => _isMuted = !_isMuted),
                  icon: Icon(
                    _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.red : Colors.white,
                    size: 32,
                  ),
                ),

                // Video on/off
                IconButton(
                  onPressed: () =>
                      setState(() => _isVideoOff = !_isVideoOff),
                  icon: Icon(
                    _isVideoOff ? Icons.videocam_off : Icons.videocam,
                    color: _isVideoOff ? Colors.red : Colors.white,
                    size: 32,
                  ),
                ),

                // End call
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.call_end,
                    color: Colors.red,
                    size: 40,
                  ),
                ),

                // Speaker toggle
                IconButton(
                  onPressed: () =>
                      setState(() => _isSpeakerOn = !_isSpeakerOn),
                  icon: Icon(
                    _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    color: _isSpeakerOn ? Colors.blue : Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class VideoCallScreen extends StatefulWidget {
  final Room room;
  final String roomName;

  const VideoCallScreen({
    super.key,
    required this.room,
    required this.roomName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  List<Participant> _participants = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _updateParticipants();
  }

  void _setupListeners() {
    widget.room.addListener(_updateParticipants);
  }

  void _updateParticipants() {
    setState(() {
      _participants = widget.room.remoteParticipants.values.toList();
    });
  }

  @override
  void dispose() {
    widget.room.removeListener(_updateParticipants);
    widget.room.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end),
            onPressed: () {
              widget.room.disconnect();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Local video (your camera - already connected)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: widget.room.localParticipant != null
                  ? VideoTrackWidget(
                      participant: widget.room.localParticipant!,
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),
          // Remote participants
          Expanded(
            flex: 2,
            child: _participants.isEmpty
                ? const Center(
                    child: Text('Waiting for others to join...'),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      return VideoTrackWidget(
                        participant: _participants[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class VideoTrackWidget extends StatelessWidget {
  final Participant participant;

  const VideoTrackWidget({
    super.key,
    required this.participant,
  });

  @override
  Widget build(BuildContext context) {
    final videoTrack = participant.videoTrackPublications.firstOrNull?.track as VideoTrack?;
    
    if (videoTrack == null) {
      return Container(
        color: Colors.grey[800],
        child: Center(
          child: Text(
            participant.identity,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return VideoTrackRenderer(
      videoTrack,
      fit: VideoViewFit.cover,
    );
  }
}

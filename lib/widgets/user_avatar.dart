import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double radius;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
        onBackgroundImageError: (_, __) {},
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../server.dart';
import '../user.dart';

class _ProfileSection extends StatelessWidget {
  final Widget child;

  const _ProfileSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}

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

      body: SingleChildScrollView(
        child : Column(
            children: [
                _ProfileSection(
                    child: Row(
                        children: [
                            CircleAvatar(radius: 36,),
                            const SizedBox(width: 16),
                            Text('John Doe'),
                        ],
                    ),
                ),
            ],
        ),
        
      ),

    );
  }
}
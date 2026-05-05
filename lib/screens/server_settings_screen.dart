import 'package:flutter/material.dart';
import '../server_api/server.dart';

enum StatusType { success, error, info }

class ServerSettingsScreen extends StatefulWidget {
  final Server server;

  const ServerSettingsScreen({super.key, required this.server});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _serverUrlController = TextEditingController(text: 'http://');

  bool _isTestingConnection = false;
  bool _isSavingUrl = false;
  bool _connectionWasSuccessful = false;
  String? _statusMessage;
  StatusType _statusType = StatusType.info;

  // Checks if the URL field has something meaningful in it
  bool _userHasEnteredUrl() {
    final url = _serverUrlController.text.trim();
    return url.isNotEmpty && url != 'http://';
  }

  // Sets the status message along with its type
  void _setStatus(String message, StatusType type) {
    setState(() {
      _statusMessage = message;
      _statusType = type;
    });
  }

  // Returns the appropriate color for the current status type
  Color _statusColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (_statusType) {
      case StatusType.success:
        return Colors.green;
      case StatusType.error:
        return colorScheme.error;
      case StatusType.info:
        return colorScheme.onSurfaceVariant;
    }
  }

  // Temporarily applies the entered URL and tests if the server responds
  Future<void> _testConnection() async {
    if (!_userHasEnteredUrl()) {
      _setStatus('Please enter a server URL.', StatusType.error);
      _connectionWasSuccessful = false;
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _statusMessage = null;
      _connectionWasSuccessful = false;
    });

    widget.server.setServerUrl(_serverUrlController.text.trim());
    final bool serverIsReachable = await widget.server.testServerConnection();

    setState(() {
      _isTestingConnection = false;
      _connectionWasSuccessful = serverIsReachable;
    });

    if (serverIsReachable) {
      _setStatus('Connection successful! You can now save.', StatusType.success);
    } else {
      _setStatus('Could not reach the server. Check the URL and try again.', StatusType.error);
    }
  }

  // Saves the server URL to device storage
  Future<void> _saveServerUrl() async {
    setState(() => _isSavingUrl = true);

    await widget.server.saveServerUrl(_serverUrlController.text.trim());

    setState(() => _isSavingUrl = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL saved.')),
      );
    }
  }

  // Loads the previously saved server URL from device storage into the text field
  Future<void> _loadSavedServerUrl() async {
    await widget.server.loadServerUrl();
    final String? savedUrl = widget.server.getServerUrl();

    if (savedUrl != null && savedUrl.isNotEmpty) {
      _serverUrlController.text = savedUrl;
      _connectionWasSuccessful = false;
      _setStatus('Loaded saved URL.', StatusType.info);
    } else {
      _connectionWasSuccessful = false;
      _setStatus('No saved URL found.', StatusType.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter your server URL',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Example: http://192.168.1.10:8000',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _serverUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                prefixIcon: Icon(Icons.dns_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _loadSavedServerUrl,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Load Saved URL'),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _isTestingConnection ? null : _testConnection,
              icon: _isTestingConnection
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find_outlined),
              label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _connectionWasSuccessful && !_isSavingUrl ? _saveServerUrl : null,
              icon: _isSavingUrl
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSavingUrl ? 'Saving...' : 'Save Server URL'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }
}
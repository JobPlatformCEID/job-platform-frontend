import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'theme/app_theme.dart';
import 'server.dart';
import 'auth.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  // Required before any async work in main
  WidgetsFlutterBinding.ensureInitialized();

  // Set up logger
  Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
  Logger.root.onRecord.listen((record) {
    debugPrint('[${record.loggerName}] ${record.level.name}: ${record.message}'
        '${record.error != null ? '\nError: ${record.error}' : ''}');
  });

  // Create the server and user instances
  final server = Server();
  final auth = Auth(server: server);

  // Load saved data from storage
  await server.loadServerUrl();
  final bool hasSession = await auth.loadSession();

  runApp(MyApp(server: server, auth: auth, hasSession: hasSession));
}

class MyApp extends StatelessWidget {
  final Server server;
  final Auth auth;
  final bool hasSession;

  const MyApp({super.key, required this.server, required this.auth, required this.hasSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: _pickStartScreen(),
    );
  }

  Widget _pickStartScreen() {
    if (hasSession) return MainScreen(server: server, auth: auth);
    return WelcomeScreen(server: server, auth: auth);
  }
}
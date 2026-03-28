import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'server/server.dart';
import 'screens/server_settings_screen.dart';

void main() async {
  // Required before any async work in main
  WidgetsFlutterBinding.ensureInitialized();

  // Create the server instance and load any saved URL
  final server = Server();
  await server.loadServerUrl();

  runApp(MyApp(server: server));
}

class MyApp extends StatelessWidget {
  final Server server;

  const MyApp({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: ServerSettingsScreen(server: server),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const ProviderScope(child: UiucSubleaseApp()));
}

class UiucSubleaseApp extends StatelessWidget {
  const UiucSubleaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UIUC Sublease',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.orange),
      home: const AuthGate(),
    );
  }
}

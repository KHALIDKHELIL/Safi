import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'screens/auth_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    const ProviderScope(
      child: SafiApp(),
    ),
  );
}

class SafiApp extends ConsumerWidget {
  const SafiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch the current theme mode in real-time
    final currentThemeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Safi',
      debugShowCheckedModeBanner: false,
      themeMode: currentThemeMode, // 2. Bind the mode to Riverpod
      
      // 3. Define the LIGHT Theme
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      
      // 4. Define the DARK Theme
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      
      // 5. App launches to the AuthScreen first to enforce biometric security
      home: const AuthScreen(),
    );
  }
}
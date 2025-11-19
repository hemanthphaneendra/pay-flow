import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';

/// Manually provided Firebase options for web (and default for other platforms if desired).
/// In production consider using `flutterfire configure` to generate `firebase_options.dart`.
const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyDfL7yoxZiWnDBZnGBCpTytnWucrq9RnzA",
  authDomain: "payflow-3e2b5.firebaseapp.com",
  projectId: "payflow-3e2b5",
  storageBucket: "payflow-3e2b5.firebasestorage.app",
  messagingSenderId: "507412841653",
  appId: "1:507412841653:web:578ab011d407d271a26afc",
  measurementId: "G-KKW7S2Q59V",
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase (for web supply explicit options, for others attempt default).
  try {
    await Firebase.initializeApp(options: _webFirebaseOptions);
  } catch (e) {
    // If already initialized or running on mobile with default config generated later.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue.shade700,
    );
    return MaterialApp(
      title: 'Pay Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseColorScheme.copyWith(
          primary: Colors.blue.shade700,
          secondary: Colors.blue.shade400,
        ),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.blue.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blue.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blue.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: baseColorScheme.error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          labelStyle: TextStyle(color: Colors.blue.shade700),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.white.withValues(alpha: 0.85),
          elevation: 0,
          foregroundColor: Colors.blue.shade900,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

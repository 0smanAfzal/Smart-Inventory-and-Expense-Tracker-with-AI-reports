import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_inventory/providers/auth_provider.dart';
import 'package:smart_inventory/providers/theme_provider.dart';
import 'package:smart_inventory/screens/login_screen.dart';
import 'package:smart_inventory/screens/main_navigation.dart';
import 'package:smart_inventory/screens/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, child) {
          // SHOW SPLASH SCREEN WHILE CHECKING AUTH
          if (authProvider.isLoading) {
            return MaterialApp(
              title: 'Inventory & Expense Tracker',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF667eea)),
                useMaterial3: true,
              ),
              home: const SplashScreen(),
            );
          }

          return MaterialApp(
            title: 'Inventory & Expense Tracker',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF667eea)),
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF667eea),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            themeMode: themeProvider.themeMode,
            home: authProvider.isAuthenticated
                ? const MainNavigation()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
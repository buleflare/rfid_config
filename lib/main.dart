import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rfid_v1/screens/access_bits_tool_screen.dart';
import 'screens/home_screen.dart';
import 'screens/read_screen.dart';
import 'screens/write_screen.dart';
import 'screens/config_screen.dart';
import 'screens/calculator_screen.dart';
import 'providers/nfc_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NfcProvider()..initializeKeys()),
        ChangeNotifierProvider(create: (_) => NfcProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mifare Classic 1K RFID Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const HomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/read': (context) => const ReadScreen(),
        '/write': (context) => const WriteScreen(),
        '/config': (context) => const ConfigScreen(),
        '/calculator': (context) => const CalculatorScreen(),
        '/access_tool': (context) => const AccessBitsToolScreen(),
      },
    );
  }
}
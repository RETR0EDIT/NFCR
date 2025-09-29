import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const NFCRApp());
}

class NFCRApp extends StatelessWidget {
  const NFCRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFCR - NFC Card Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

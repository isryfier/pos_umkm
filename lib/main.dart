import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

/// Titik masuk aplikasi.
void main() {
  runApp(const PosKulinerApp());
}

class PosKulinerApp extends StatelessWidget {
  const PosKulinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Kuliner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Warna oranye hangat, cocok untuk nuansa kuliner.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      // Halaman pertama yang tampil adalah halaman login.
      home: const LoginScreen(),
    );
  }
}

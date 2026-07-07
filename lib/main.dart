import 'package:flutter/material.dart';
import 'screens/pantalla_principal.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Configuración principal de la aplicación
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión Interna de Viáticos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const PantallaPrincipal(),
    );
  }
}
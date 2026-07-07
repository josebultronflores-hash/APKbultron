import 'package:flutter/material.dart';

import '../widgets/opcion_menu_card.dart';
import 'solicitud_qls_screen.dart';
import 'informe_qls_screen.dart';

class PantallaQLS extends StatelessWidget {
  const PantallaQLS({super.key});



  // Pantalla específica para QLS Panamá con opciones de menú
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('QLS Panamá'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 25),

            Image.asset(
              'assets/images/qls_panama.png',
              height: 120,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 25),

            const Text(
              'Menú QLS Panamá',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Seleccione el tipo de documento',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 40),

            OpcionMenuCard(
              titulo: 'Solicitud de Viáticos QLS',
              subtitulo: 'Crear una nueva solicitud de viáticos',
              icono: Icons.description,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SolicitudQlsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            OpcionMenuCard(
                titulo: 'Informe de Viáticos QLS',
                subtitulo: 'Crear un informe de gastos o viáticos',
                icono: Icons.assignment,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InformeQlsScreen(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
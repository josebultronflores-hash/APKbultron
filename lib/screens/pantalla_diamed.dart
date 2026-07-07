import 'package:flutter/material.dart';

import '../widgets/opcion_menu_card.dart';
import 'solicitud_diamed_screen.dart';
import 'informe_diamed_screen.dart';

class PantallaDiamed extends StatelessWidget {
  const PantallaDiamed({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Diamed Panamá'),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 25),

            Image.asset(
              'assets/images/diamed_panama.png',
              height: 130,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 25),

            const Text(
              'Menú Diamed Panamá',
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

            // TARJETA 1: SOLICITUD DE VIÁTICOS DIAMED
            OpcionMenuCard(
              titulo: 'Solicitud de Viáticos Diamed',
              subtitulo: 'Crear una nueva solicitud de viáticos',
              icono: Icons.description,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SolicitudDiamedScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // TARJETA 2: INFORME DE VIÁTICOS DIAMED
            OpcionMenuCard(
              titulo: 'Informe de Viáticos Diamed',
              subtitulo: 'Crear un informe de gastos o viáticos',
              icono: Icons.assignment,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InformeDiamedScreen(),
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
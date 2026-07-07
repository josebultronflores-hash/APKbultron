import 'package:flutter/material.dart';

class EditorCoordenadasScreen extends StatefulWidget {
  const EditorCoordenadasScreen({super.key});

  @override
  State<EditorCoordenadasScreen> createState() =>
      _EditorCoordenadasScreenState();
}

class _EditorCoordenadasScreenState extends State<EditorCoordenadasScreen> {
  double empleadoX = 176;
  double empleadoY = 105;

  double fechaX = 461;
  double fechaY = 121;

  final double plantillaWidth = 595;  // ancho usado en tu PDF
  final double plantillaHeight = 842; // alto usado en tu PDF

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de coordenadas'),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Center(
          child: SizedBox(
            width: plantillaWidth,
            height: plantillaHeight,
            child: Stack(
              children: [
                Image.asset(
                  'assets/templates/solicitud_qls_template.png',
                  width: plantillaWidth,
                  height: plantillaHeight,
                  fit: BoxFit.fill,
                ),

                _campoMovible(
                  texto: 'JOSE BULTRON',
                  x: empleadoX,
                  y: empleadoY,
                  onMove: (dx, dy) {
                    setState(() {
                      empleadoX += dx;
                      empleadoY += dy;
                    });
                  },
                ),

                _campoMovible(
                  texto: '26/06/2026',
                  x: fechaX,
                  y: fechaY,
                  onMove: (dx, dy) {
                    setState(() {
                      fechaX += dx;
                      fechaY += dy;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.black87,
        child: Text(
          '''
Empleado: left=${empleadoX.toStringAsFixed(1)}, top=${empleadoY.toStringAsFixed(1)}
Fecha: left=${fechaX.toStringAsFixed(1)}, top=${fechaY.toStringAsFixed(1)}
''',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }

  Widget _campoMovible({
    required String texto,
    required double x,
    required double y,
    required Function(double dx, double dy) onMove,
  }) {
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (details) {
          onMove(details.delta.dx, details.delta.dy);
        },
        child: Container(
          padding: const EdgeInsets.all(2),
          color: Colors.yellow.withValues(alpha: 0.5),
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

// Widget personalizado para mostrar el logo de la empresa
class EmpresaCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String logoAsset;
  final Color color;
  final VoidCallback onTap;

  const EmpresaCard({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.logoAsset,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Image.asset(
                logoAsset,
                height: 110,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
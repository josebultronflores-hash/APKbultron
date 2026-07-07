import 'dart:async';

import 'package:flutter/material.dart';

void mostrarLoadingPdf(
  BuildContext context, {
  String mensaje = 'Generando PDF',
  String subMensaje = 'Por favor espere',
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return _LoadingConPuntos(
        mensaje: mensaje,
        subMensaje: subMensaje,
      );
    },
  );
}

void cerrarLoadingPdf(BuildContext context) {
  if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}

class _LoadingConPuntos extends StatefulWidget {
  final String mensaje;
  final String subMensaje;

  const _LoadingConPuntos({
    required this.mensaje,
    required this.subMensaje,
  });

  @override
  State<_LoadingConPuntos> createState() => _LoadingConPuntosState();
}

class _LoadingConPuntosState extends State<_LoadingConPuntos> {
  int cantidadPuntos = 1;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
      const Duration(milliseconds: 450),
      (_) {
        if (!mounted) return;

        setState(() {
          cantidadPuntos++;

          if (cantidadPuntos > 3) {
            cantidadPuntos = 1;
          }
        });
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final puntos = '.' * cantidadPuntos;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 26,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Color(0xFF002B6B),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              '${widget.mensaje}$puntos',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002B6B),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              widget.subMensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
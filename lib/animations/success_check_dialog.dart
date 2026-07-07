import 'package:flutter/material.dart';

Future<void> mostrarCheckGuardado(
  BuildContext context, {
  String mensaje = 'Guardado correctamente',
}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: _CheckAnimado(mensaje: mensaje),
        ),
      );
    },
  );

  await Future.delayed(const Duration(seconds: 2));

  if (context.mounted && Navigator.canPop(context)) {
    Navigator.pop(context);
  }
}

class _CheckAnimado extends StatefulWidget {
  final String mensaje;

  const _CheckAnimado({
    required this.mensaje,
  });

  @override
  State<_CheckAnimado> createState() => _CheckAnimadoState();
}

class _CheckAnimadoState extends State<_CheckAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 24,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Container(
              width: 86,
              height: 86,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 58,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '¡Éxito!',
              style: TextStyle(
                color: Colors.green,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
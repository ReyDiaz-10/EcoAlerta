import 'package:flutter/material.dart';

class FondoEcoAlerta extends StatelessWidget {
  final Widget child;

  const FondoEcoAlerta({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Degradado ecológico sutil
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9), // Verde muy claro
            Color(0xFFC8E6C9), // Verde suave
            Color(0xFFA5D6A7), // Verde medio
          ],
        ),
      ),
      child: Stack(
        children: [
          // Capa de textura de puntos
          Positioned.fill(
            child: CustomPaint(
              painter: PuntoTexturaPainter(),
            ),
          ),
          // Contenido principal de la pantalla
          SafeArea(child: child),
        ],
      ),
    );
  }
}

// Clase para dibujar los puntos (textura minimalista)
class PuntoTexturaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05) // Puntos muy sutiles
      ..strokeWidth = 1.0;

    const double espacio = 25.0; // Distancia entre puntos
    for (double i = 0; i < size.width; i += espacio) {
      for (double j = 0; j < size.height; j += espacio) {
        canvas.drawCircle(Offset(i, j), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

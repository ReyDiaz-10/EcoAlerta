import 'package:flutter/material.dart';

class BotonIdiomaDinamico extends StatefulWidget {
  final VoidCallback? onPressed;

  const BotonIdiomaDinamico({super.key, this.onPressed});

  @override
  State<BotonIdiomaDinamico> createState() => _BotonIdiomaDinamicoState();
}

class _BotonIdiomaDinamicoState extends State<BotonIdiomaDinamico> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        widget.onPressed?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12), // Bordes redondeados suaves
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: _isPressed
              ? [] // Sin sombra cuando se simula que se "hunde"
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 3), // Dirección de la sombra
                  )
                ],
        ),
        transform: _isPressed
            ? Matrix4.translationValues(
                0, 2, 0) // Desplazamiento físico hacia abajo
            : Matrix4.identity(),
        child: Text(
          "EN",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

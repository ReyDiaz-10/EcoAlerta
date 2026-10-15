import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BotonEmergencia123 extends StatelessWidget {
  const BotonEmergencia123({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(30), // Bordes redondeados y muy suaves
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(
                0, 5), // Sombra acentuada hacia abajo para el relieve
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () async {
          final uri = Uri.parse('tel:123');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },
        icon: const Icon(Icons.phone_in_talk, color: Colors.white),
        label: const Text(
          "Llamar al 123",
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation:
              0, // Desactivamos la elevación nativa para usar nuestra boxShadow en relieve
        ),
      ),
    );
  }
}

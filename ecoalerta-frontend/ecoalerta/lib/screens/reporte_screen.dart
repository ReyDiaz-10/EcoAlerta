import 'package:flutter/material.dart';
// Asegúrate de importar tu archivo de widgets
import '../widgets/fondo_degradado.dart';

class ReporteScreen extends StatelessWidget {
  const ReporteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // La estructura envuelve al Scaffold y asegura transparencia
    return FondoEcoAlerta(
      child: Scaffold(
        backgroundColor: Colors.transparent, // ¡Indispensable!
        appBar: AppBar(
          title: const Text("EcoAlerta"),
          backgroundColor: Colors.transparent, // AppBar transparente
          elevation: 0,
          foregroundColor: Colors.blueGrey.shade800, // Color del título
        ),
        body: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Reporte de incidentes",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 20),
              // Aquí irían tus botones o inputs, por ejemplo:
              ElevatedButton(
                onPressed: () {},
                child: const Text("Subir Foto del Incidente"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

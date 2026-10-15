import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  final String idioma;

  const AboutScreen({super.key, required this.idioma});

  final Map<String, Map<String, String>> textosAbout = const {
    'ES': {
      'titulo': 'Acerca de EcoAlerta',
      'descripcion':
          'EcoAlerta es una plataforma tecnológica avanzada para la participación ciudadana en el cuidado de nuestros ecosistemas. A través de esta aplicación, puedes reportar de manera inmediata problemáticas críticas como acumulación inadecuada de basuras, vertimientos ilegales en fuentes de agua, talas de árboles no autorizadas, contaminación auditiva o del aire, e incendios forestales.',
      'instrucciones':
          '¿Qué puedes hacer?\n1. Generar reportes geolocalizados de manera exacta.\n2. Adjuntar evidencia fotográfica real capturada desde el lugar de los hechos.\n3. Clasificar los incidentes según niveles de urgencia (Bajo, Medio, Crítico).',
      'advertencia':
          '⚠️ ADVERTENCIA DE USO RESPONSABLE:\nEsta aplicación no debe ser utilizada para reportes falsos o bromas. El uso malintencionado de los canales de atención ciudadana puede desviar recursos valiosos destinados a emergencias ecológicas reales. Toda la información suministrada se procesa con absoluto rigor.',
      'version': 'Versión 1.0.0',
      'creador': 'Creado por: Neil Farith Murillo Díaz',
      'legal': 'Tratamiento de Datos (Ley 1581 de 2012 - Gobierno de Colombia)',
    },
    'EN': {
      'titulo': 'About EcoAlerta',
      'descripcion':
          'EcoAlerta is an advanced technological platform for citizen participation in preserving our ecosystems. Through this application, you can immediately report critical issues such as improper waste accumulation, illegal dumping in water sources, unauthorized logging, noise or air pollution, and forest fires.',
      'instrucciones':
          'What can you do?\n1. Generate highly accurate geolocated reports.\n2. Attach real photographic evidence taken straight from the scene.\n3. Classify incidents based on urgency levels (Low, Medium, Critical).',
      'advertencia':
          '⚠️ RESPONSIBLE USE WARNING:\nThis application must not be used for fake reports or pranks. Malicious use of citizen report channels can misdirect vital resources intended for real ecological emergencies. All submitted information is processed with absolute rigor.',
      'version': 'Version 1.0.0',
      'creador': 'Created by: Neil Farith Murillo Díaz',
      'legal': 'Data Processing (Law 1581 of 2012 - Colombia Government)',
    },
  };

  Future<void> _abrirLinkLegal() async {
    final Uri url = Uri.parse(
        'https://www.mincit.gov.co/ministerio/proteccion-de-datos-personales');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir el enlace legal');
    }
  }

  TextStyle _estiloConRelieve(
      {required double fontSize,
      required bool isBold,
      Color color = Colors.black}) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: color,
      height: 1.4,
      shadows: const [
        Shadow(
          offset: Offset(1.0, 1.0),
          blurRadius: 1.5,
          color: Colors.black12,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = textosAbout[idioma] ?? textosAbout['ES']!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          textos['titulo']!,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3),
                itemCount: 30,
                itemBuilder: (context, index) => const Icon(
                  Icons.eco,
                  size: 80,
                  color: Colors.green,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                const Icon(Icons.eco, size: 80, color: Color(0xFF4CAF50)),
                const SizedBox(height: 20),
                Text(
                  textos['titulo']!,
                  textAlign: TextAlign.center,
                  style: _estiloConRelieve(
                      fontSize: 26,
                      isBold: true,
                      color: const Color(0xFF1B5E20)),
                ),
                const SizedBox(height: 18),
                Text(
                  textos['descripcion']!,
                  textAlign: TextAlign.center,
                  style: _estiloConRelieve(fontSize: 16, isBold: false),
                ),
                const SizedBox(height: 18),
                Text(
                  textos['instrucciones']!,
                  textAlign: TextAlign.center,
                  style: _estiloConRelieve(fontSize: 16, isBold: false),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    textos['advertencia']!,
                    textAlign: TextAlign.center,
                    style: _estiloConRelieve(
                        fontSize: 14, isBold: true, color: Colors.red.shade900),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  textos['creador']!,
                  textAlign: TextAlign.center,
                  style: _estiloConRelieve(
                      fontSize: 17,
                      isBold: true,
                      color: const Color(0xFF2E7D32)),
                ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: _abrirLinkLegal,
                  child: Text(
                    textos['legal']!,
                    textAlign:
                        TextAlign.center, // CORREGIDO: "center" en minúscula
                    style: const TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        color: Colors.blueAccent),
                  ),
                ),
                Text(
                  textos['version']!,
                  style: _estiloConRelieve(
                      fontSize: 12, isBold: false, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

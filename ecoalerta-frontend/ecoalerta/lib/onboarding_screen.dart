import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final String idioma;
  final Function(String)? onComplete;
  final Function(String)? onLanguageChange;

  const OnboardingScreen({
    super.key,
    required this.idioma,
    this.onComplete,
    this.onLanguageChange,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;

  final List<Map<String, String>> onboardingPages = [
    {
      'es_title': '¿Qué es EcoAlerta?',
      'en_title': 'What is EcoAlerta?',
      'es_desc':
          'EcoAlerta es una plataforma ciudadana para reportar problemas ambientales y de infraestructura en tu ciudad.',
      'en_desc':
          'EcoAlerta is a citizen platform to report environmental and infrastructure problems in your city.',
      'icon': '🌍',
    },
    {
      'es_title': 'Reporta de forma segura',
      'en_title': 'Report safely',
      'es_desc':
          'Adjunta fotos, ubica automáticamente el lugar y envía tu reporte. Sin necesidad de registro.',
      'en_desc':
          'Attach photos, set the location automatically and send your report. No registration needed.',
      'icon': '📷',
    },
    {
      'es_title': 'IA clasifica tu reporte',
      'en_title': 'AI classifies your report',
      'es_desc':
          'Nuestra inteligencia artificial analiza las imágenes para clasificar el problema y enviarlo a la entidad correcta.',
      'en_desc':
          'Our artificial intelligence analyzes images to classify the problem and send it to the right entity.',
      'icon': '🤖',
    },
    {
      'es_title': 'Recibe seguimiento',
      'en_title': 'Get updates',
      'es_desc':
          'Recibirás notificaciones por correo sobre el estado de tu reporte y cómo avanza la gestión.',
      'en_desc':
          'You will receive email notifications about your report status and how management is progressing.',
      'icon': '📧',
    },
    {
      'es_title': 'Juntos mejoramos la ciudad',
      'en_title': 'Together we improve the city',
      'es_desc':
          'Cada reporte contribuye a mejorar el espacio público y la calidad de vida en tu comunidad.',
      'en_desc':
          'Every report contributes to improving public space and quality of life in your community.',
      'icon': '💚',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final esES = widget.idioma == 'ES';
    final page = onboardingPages[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        title: Text(esES ? 'Bienvenido a EcoAlerta' : 'Welcome to EcoAlerta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              widget.onLanguageChange?.call(esES ? 'EN' : 'ES');
            },
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(page['icon']!, style: const TextStyle(fontSize: 80)),
                  const SizedBox(height: 24),
                  Text(
                    esES ? page['es_title']! : page['en_title']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    esES ? page['es_desc']! : page['en_desc']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    onboardingPages.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentPage
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      child: Text(esES ? 'Anterior' : 'Previous'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _currentPage < onboardingPages.length - 1
                          ? () => setState(() => _currentPage++)
                          : () {
                              if (widget.onComplete != null) {
                                widget.onComplete!(widget.idioma);
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                      child: Text(
                        _currentPage < onboardingPages.length - 1
                            ? (esES ? 'Siguiente' : 'Next')
                            : (esES ? 'Empezar' : 'Start'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

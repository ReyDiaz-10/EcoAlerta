import 'package:flutter/material.dart';
import 'main.dart';

class InfoScreen extends StatefulWidget {
  final String idioma;

  const InfoScreen({super.key, required this.idioma});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final PageController pageController = PageController();
  int currentIndex = 0;

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EcoAlertaHome(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool esES = widget.idioma == 'es';

    final List<Map<String, String>> stepsData = [
      {
        "title":
            esES ? "¡Bienvenido a EcoAlerta! 🌱" : "Welcome to EcoAlerta! 🌱",
        "description": esES
            ? "Tu herramienta para reportar problemas ambientales y daños en la infraestructura del Valle de Aburrá."
            : "Your tool to report environmental issues and infrastructure damage in the Valle de Aburrá.",
      },
      {
        "title": esES ? "1. Captura el Problema 📸" : "1. Capture the Issue 📸",
        "description": esES
            ? "Toma o adjunta fotos de huecos, escombros, fallas viales o puntos críticos de basura. ¡Puedes subir varias imágenes!"
            : "Take or attach photos of potholes, debris, road failures, or trash critical points. You can upload multiple images!",
      },
      {
        "title":
            esES ? "2. Ubicación Automática 📍" : "2. Automatic Location 📍",
        "description": esES
            ? "La aplicación detectará tu ubicación por GPS automáticamente. También puedes ajustar el punto exacto navegando en el mapa."
            : "The app will automatically detect your location via GPS. You can also adjust the exact point by navigating the map.",
      },
      {
        "title":
            esES ? "3. Análisis Inteligente 🚀" : "3. Intelligent Analysis 🚀",
        "description": esES
            ? "Nuestra IA analizará las imágenes en segundo plano para clasificar el riesgo y asignar el reporte a la entidad correcta de inmediato."
            : "Our AI will analyze the images in the background to classify the risk and assign the report to the correct entity immediately.",
      }
    ];

    bool isLastPage = currentIndex == stepsData.length - 1;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: stepsData.length,
                    onPageChanged: (index) {
                      setState(() {
                        currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Text(
                                stepsData[index]["title"]!.split(" ").last,
                                style: const TextStyle(fontSize: 80),
                              ),
                            ),
                            const SizedBox(height: 40),
                            Text(
                              stepsData[index]["title"]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              stepsData[index]["description"]!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    stepsData.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 8,
                      width: currentIndex == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: currentIndex == index
                            ? Colors.green
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: currentIndex == 0
                            ? null
                            : () {
                                pageController.previousPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              },
                        child: Text(
                          esES ? "Anterior" : "Previous",
                          style: TextStyle(
                            color:
                                currentIndex == 0 ? Colors.grey : Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (isLastPage) {
                            _navigateToHome();
                          } else {
                            pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isLastPage
                              ? (esES ? "Comenzar" : "Get Started")
                              : (esES ? "Siguiente" : "Next"),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, size: 28, color: Colors.grey),
                onPressed: _navigateToHome,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

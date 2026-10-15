import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'report_form_screen.dart';
import 'about_screen.dart';
import 'widgets/fondo_degradado.dart';
import 'admin_login_screen.dart';
import 'onboarding_screen.dart';
import 'theme/ecoalerta_theme.dart';
import 'tracking_screen.dart';
import 'config/api_config.dart';

void main() => runApp(const EcoAlertaApp());

class EcoAlertaApp extends StatelessWidget {
  const EcoAlertaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoAlerta',
      theme: EcoAlertaTheme.light,
      home: const OnboardingScreenWrapper(),
    );
  }
}

// Wrapper para pasar el idioma al OnboardingScreen
class OnboardingScreenWrapper extends StatefulWidget {
  const OnboardingScreenWrapper({super.key});

  @override
  State<OnboardingScreenWrapper> createState() =>
      _OnboardingScreenWrapperState();
}

class _OnboardingScreenWrapperState extends State<OnboardingScreenWrapper> {
  String idioma = 'ES';

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      idioma: idioma,
      onComplete: (nuevoIdioma) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => EcoAlertaHome(idioma: nuevoIdioma)),
        );
      },
      onLanguageChange: (nuevoIdioma) {
        setState(() => idioma = nuevoIdioma);
      },
    );
  }
}

class EcoAlertaHome extends StatefulWidget {
  final String idioma;

  const EcoAlertaHome({super.key, this.idioma = 'ES'});

  @override
  State<EcoAlertaHome> createState() => _EcoAlertaHomeState();
}

class _EcoAlertaHomeState extends State<EcoAlertaHome> {
  late String idioma;
  final Color verdeOscuro = const Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    idioma = widget.idioma;
  }

  // Política propia, pública y en el mismo dominio HTTPS de EcoAlerta.
  Future<void> _abrirTratamientoDatos() async {
    final Uri url = ApiConfig.privacyPolicyUrl;
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'No se pudo abrir el enlace $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool esES = idioma == 'ES';

    return FondoEcoAlerta(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.language, color: verdeOscuro),
            onPressed: () => setState(() => idioma = esES ? 'EN' : 'ES'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.red),
              onPressed: () => launchUrl(Uri.parse('tel:123')),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco, size: 100, color: verdeOscuro),
              const SizedBox(height: 10),
              Text(
                "EcoAlerta",
                style: TextStyle(
                  fontSize: 40,
                  color: verdeOscuro,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  esES
                      ? "Gracias por ayudarnos a ayudar, cada reporte cuenta."
                      : "Thank you for helping us help, every report counts.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: verdeOscuro),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportFormScreen(idioma: idioma),
                  ),
                ),
                child: Text(
                  esES ? "Reportar Incidente" : "Report Incident",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrackingScreen(idioma: idioma),
                  ),
                ),
                child: Text(
                  esES ? "Consultar mi reporte" : "Track my report",
                  style: TextStyle(color: verdeOscuro),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OnboardingScreen(idioma: idioma),
                  ),
                ),
                child: Text(
                  esES ? "¿Cómo funciona?" : "How it works?",
                  style: TextStyle(color: verdeOscuro),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AboutScreen(idioma: idioma),
                  ),
                ),
                child: Text(
                  esES ? "Acerca de la Aplicación" : "About the App",
                  style: TextStyle(color: verdeOscuro),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                ),
                child: Text(
                  esES ? "Acceso Admin" : "Admin Login",
                  style: TextStyle(color: verdeOscuro),
                ),
              ),
              // Nuevo botón para acceder al PDF de Tratamiento de Datos
              TextButton(
                onPressed: _abrirTratamientoDatos,
                child: Text(
                  esES
                      ? "Política de Tratamiento de Datos"
                      : "Data Privacy Policy",
                  style: TextStyle(
                    color: verdeOscuro,
                    decoration: TextDecoration.underline,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

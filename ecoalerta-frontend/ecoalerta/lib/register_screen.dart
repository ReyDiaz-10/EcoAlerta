import 'services/ai_service.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  final String idioma;
  final String descripcion;
  final String direccionReporte;
  final double latitud;
  final double longitud;
  final String radicadoOriginal;
  final String analysisToken;
  // Añadimos la lista de imágenes que viene desde el formulario
  final List<Uint8List> listaImagenesBytes;

  const RegisterScreen({
    super.key,
    required this.idioma,
    required this.descripcion,
    required this.direccionReporte,
    required this.latitud,
    required this.longitud,
    required this.radicadoOriginal,
    required this.analysisToken,
    required this.listaImagenesBytes, // Parámetro requerido
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _estaProcesando = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // FUNCIÓN REAL: Conecta con FastAPI y procesa la auditoría de la IA
  Future<void> _enviarReporteAlBackend() async {
    setState(() {
      _estaProcesando =
          true; // Activa la animación de carga con el mensaje humano
    });

    // Consumimos el servicio enviando los datos heredados
    final resultado = await AIService.enviarYClasificarReporte(
      descripcion: widget.descripcion,
      direccion: widget.direccionReporte,
      latitud: widget.latitud,
      longitud: widget.longitud,
      imagenes: widget.listaImagenesBytes,
      correoUsuario: _emailController.text,
      nombreUsuario: _nameController.text,
      direccionUsuario: _addressController.text,
      radicadoOriginal: widget.radicadoOriginal,
      origen: 'app',
      analysisToken: widget.analysisToken,
    );

    if (!mounted) return;

    setState(() {
      _estaProcesando = false; // Apaga el indicador de carga
    });

    // Evaluamos la respuesta estructurada que retornó el prompt avanzado de la IA
    if (resultado['success'] == true && resultado['analisis'] is Map) {
      _mostrarDialogoExito(
        entidad: resultado['entidad_assigned']?.toString() ?? '',
        analisis: resultado['analisis'] as Map<String, dynamic>,
        radicado: resultado['radicado']?.toString() ?? '',
        codigoConsulta: resultado['codigo_consulta']?.toString() ?? '',
        estado: resultado['estado']?.toString() ?? '',
        requiereRevision: resultado['requires_manual_review'] == true,
      );
    } else {
      String mensajeError = widget.idioma == "ES"
          ? "El reporte no pudo ser validado por la IA o hubo un problema de consistencia."
          : "The report could not be validated by the IA or there was a consistency issue.";

      if (resultado['error'] != null) {
        mensajeError = resultado['error'];
      } else if (resultado['analisis'] != null &&
          resultado['analisis']['justificacion'] != null) {
        mensajeError = resultado['analisis']['justificacion'];
      }

      _mostrarDialogoError(mensajeError);
    }
  }

  void _mostrarDialogoExito({
    required String entidad,
    required Map<String, dynamic> analisis,
    required String radicado,
    required String codigoConsulta,
    required String estado,
    required bool requiereRevision,
  }) {
    bool esES = widget.idioma == "ES";
    final tipoProblema = analisis['tipo_problema']?.toString() ?? '';
    final nivelPeligro = analisis['nivel_peligro']?.toString() ?? '';
    final descripcionIA = analisis['descripcion_ia']?.toString() ?? '';
    final evaluacionRiesgo = analisis['evaluacion_riesgo']?.toString() ?? '';
    final prioridad = analisis['prioridad']?.toString() ?? '';
    final entidadDestino = analisis['entidad_destino']?.toString() ?? '';
    final justificacion = analisis['justificacion']?.toString() ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text(esES ? "¡Reporte Recibido!" : "Report Received!"),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(
                requiereRevision
                    ? (esES
                        ? "Tu reporte fue recibido y quedó pendiente de revisión humana."
                        : "Your report was received and is pending human review.")
                    : (esES
                        ? "La IA analizó tus imágenes y clasificó el reporte con éxito."
                        : "The AI analyzed your images and classified the report successfully."),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF43A047)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esES ? 'Guarda estos datos' : 'Save these details',
                      style: const TextStyle(
                        color: Color(0xFF1B5E20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText('${esES ? 'Radicado' : 'Filing number'}: $radicado'),
                    const SizedBox(height: 4),
                    SelectableText('${esES ? 'Código de consulta' : 'Lookup code'}: $codigoConsulta'),
                    const SizedBox(height: 4),
                    Text('${esES ? 'Estado' : 'Status'}: $estado'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "${esES ? 'Entidad asignada' : 'Assigned entity'}: $entidad",
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${esES ? 'Destino del reporte' : 'Report destination'}: $entidadDestino",
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                "${esES ? 'Tipo de problema' : 'Problem type'}: $tipoProblema",
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                "${esES ? 'Nivel de peligro' : 'Danger level'}: $nivelPeligro",
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                "${esES ? 'Prioridad' : 'Priority'}: $prioridad",
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                "${esES ? 'Descripción visual' : 'Visual description'}:",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(descripcionIA, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              Text(
                "${esES ? 'Evaluación de riesgo' : 'Risk evaluation'}:",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(evaluacionRiesgo, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              Text(
                justificacion,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                esES
                    ? "Gracias por tu compromiso con el medio ambiente. Si dejaste tu correo, recibirás notificaciones sobre el avance de este reporte."
                    : "Thank you for your commitment to the environment. If you left your email, you will receive notifications about the progress of this report.",
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoError(String mensaje) {
    bool esES = widget.idioma == "ES";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(esES ? "Reporte Rechazado" : "Report Rejected"),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  TextStyle _estiloConRelieve({
    required double fontSize,
    required bool isBold,
    Color color = Colors.black,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: color,
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
    bool esES = widget.idioma == "ES";

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        title: Text(
          esES ? "Registro Ciudadano" : "Citizen Registration",
          style: _estiloConRelieve(
            fontSize: 20,
            isBold: true,
            color: Colors.white,
          ),
        ),
      ),
      body: _estaProcesando
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF2E7D32),
                      ),
                      strokeWidth: 5,
                    ),
                    const SizedBox(height: 30),
                    Icon(
                      Icons.volunteer_activism,
                      size: 45,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      esES
                          ? "Estamos trabajando para hacer llegar tu reporte directamente a la entidad correcta.\n\n¡Muchas gracias por tu valioso compromiso con nuestro entorno!"
                          : "We are working to deliver your report directly to the correct entity.\n\nThank you very much for your valuable commitment to our environment!",
                      textAlign: TextAlign.center,
                      style: _estiloConRelieve(
                        fontSize: 16,
                        isBold: true,
                        color: const Color(0xFF1B5E20),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_add,
                    size: 70,
                    color: Color(0xFF4CAF50),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    esES
                        ? "¡Tu identidad nos ayuda!"
                        : "Your identity helps us!",
                    textAlign: TextAlign.center,
                    style: _estiloConRelieve(
                      fontSize: 22,
                      isBold: true,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    esES
                        ? "Déjanos tus datos si deseas recibir el estado de tu reporte. Recuerda que este paso no es obligatorio."
                        : "Leave us your details if you wish to receive your report status. Remember this step is not mandatory.",
                    textAlign: TextAlign.center,
                    style: _estiloConRelieve(
                      fontSize: 14,
                      isBold: false,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: esES
                          ? "Nombre completo (Opcional)"
                          : "Full Name (Optional)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      prefixIcon: const Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: esES
                          ? "Correo electrónico (Opcional)"
                          : "Email Address (Optional)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      prefixIcon: const Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: esES
                          ? "Dirección de residencia (Opcional)"
                          : "Home Address (Optional)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      prefixIcon: const Icon(Icons.home),
                    ),
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      onPressed:
                          _estaProcesando ? null : _enviarReporteAlBackend,
                      child: _estaProcesando
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              esES
                                  ? "Registrarse y Enviar"
                                  : "Register & Submit",
                              style: _estiloConRelieve(
                                fontSize: 16,
                                isBold: true,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

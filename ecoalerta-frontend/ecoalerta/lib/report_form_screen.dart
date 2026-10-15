import 'dart:async';
import 'dart:convert'; // Necesario para procesar el JSON de la dirección
import 'package:flutter/foundation.dart';
import 'package:http/http.dart'
    as http; // Necesario para consultar el servidor de mapas
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'register_screen.dart';
import 'config/api_config.dart';

class ReportFormScreen extends StatefulWidget {
  final String idioma;

  const ReportFormScreen({super.key, required this.idioma});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final MapController _dialogMapController = MapController();

  // CORREGIDO: Coordenadas iniciales por defecto en el Valle de Aburrá (Medellín)
  double _latitude = 6.244;
  double _longitude = -75.574;

  double _tempLatitude = 6.244;
  double _tempLongitude = -75.574;

  bool _aceptaDatos = false;
  String _selectedPriority = "green";

  // Lista para soportar múltiples fotos
  final List<Uint8List> _listaImagenes = [];
  bool isAnalyzing = false;
  Map<String, dynamic>? aiResponse;
  String? _analysisToken;
  String? _aiErrorMessage;
  final ImagePicker _picker = ImagePicker();

  bool get _canSendReport {
    return _aceptaDatos &&
        _listaImagenes.isNotEmpty &&
        !isAnalyzing &&
        aiResponse != null &&
        _aiErrorMessage == null;
  }

  // Límite de 7MB (7 * 1024 * 1024 bytes = 7340032 bytes)
  final int _limiteBytes = 7340032;

  // Estado para controlar visualmente si se está consultando la dirección
  bool _obteniendoDireccion = false;
  bool _obteniendoUbicacion = false;
  bool _ubicacionConfirmada = false;
  bool _precisionReducida = false;
  bool _locationDisclosureAccepted = false;
  double? _precisionMetros;
  String? _mensajeUbicacion;

  // NUEVO MÉTODO: Traduce lat/lng a nomenclatura de calle real (Envigado, Medellín, Itagüí, etc.)
  Future<void> _getDirectionFromCoordinates(double lat, double lng) async {
    if (!mounted) return;
    setState(() => _obteniendoDireccion = true);

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'EcoAlertaApp'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final String direccionCompleta = data['display_name'] ?? '';

        // Formateamos para obtener un texto limpio y reconocible (ej: Calle 50, Medellín)
        List<String> partes = direccionCompleta.split(',');
        String direccionCorta = partes.length > 2
            ? "${partes[0].trim()}, ${partes[1].trim()}"
            : direccionCompleta;

        setState(() {
          _addressController.text =
              direccionCorta; // Asigna el texto automáticamente al campo de entrada
        });
      }
    } catch (e) {
      debugPrint("Error al obtener la dirección en el Valle de Aburrá: $e");
    } finally {
      if (mounted) {
        setState(() => _obteniendoDireccion = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationDisclosureAndStart();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _dialogMapController.dispose();
    super.dispose();
  }

  // Obtiene varias lecturas y conserva la más precisa. En Android la primera
  // lectura puede provenir de la red y tener un margen de error muy amplio.
  Future<void> _getCurrentLocation() async {
    if (_obteniendoUbicacion) return;
    final bool esES = widget.idioma == "ES";

    if (mounted) {
      setState(() {
        _obteniendoUbicacion = true;
        _mensajeUbicacion = esES
            ? "Buscando una señal GPS precisa…"
            : "Searching for an accurate GPS signal…";
      });
    }

    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _mensajeUbicacion = esES
              ? "La ubicación del teléfono está desactivada. Actívala y vuelve a intentar."
              : "Phone location is disabled. Enable it and try again.";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _mensajeUbicacion = esES
              ? "EcoAlerta necesita permiso de ubicación. Habilítalo en los ajustes de la aplicación."
              : "EcoAlerta needs location permission. Enable it in the app settings.";
        });
        return;
      }

      final LocationAccuracyStatus accuracyStatus =
          await Geolocator.getLocationAccuracy();
      _precisionReducida =
          accuracyStatus == LocationAccuracyStatus.reduced;

      // iOS permite conceder ubicación aproximada. Para el reporte se solicita
      // precisión completa solo durante esta sesión y únicamente tras la
      // divulgación previa de EcoAlerta; si el usuario no la concede, el mapa
      // manual sigue disponible.
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          _precisionReducida) {
        try {
          await Geolocator.requestTemporaryFullAccuracy(
            purposeKey: 'EcoAlertaReportLocation',
          );
          _precisionReducida =
              await Geolocator.getLocationAccuracy() ==
              LocationAccuracyStatus.reduced;
        } catch (error) {
          debugPrint(
            'No se concedió precisión temporal completa en iOS: $error',
          );
        }
      }

      Position? bestPosition;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final Position candidate = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 20),
          );
          if (bestPosition == null ||
              candidate.accuracy < bestPosition.accuracy) {
            bestPosition = candidate;
          }
          if (candidate.accuracy <= 20) break;
          await Future<void>.delayed(const Duration(seconds: 2));
        } on TimeoutException {
          // Conserva la mejor lectura anterior si una medición agota el tiempo.
        }
      }

      if (bestPosition == null) {
        throw TimeoutException("No se obtuvo una lectura GPS válida");
      }

      final Position position = bestPosition;
      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _tempLatitude = position.latitude;
        _tempLongitude = position.longitude;
        _precisionMetros = position.accuracy;
        _ubicacionConfirmada = true;
        if (_precisionReducida) {
          _mensajeUbicacion = esES
              ? "El teléfono está entregando una ubicación aproximada. Activa ‘Ubicación precisa’."
              : "The phone is providing an approximate location. Enable ‘Precise Location’.";
        } else if (position.accuracy <= 25) {
          _mensajeUbicacion = esES
              ? "Ubicación GPS precisa confirmada."
              : "Accurate GPS location confirmed.";
        } else {
          _mensajeUbicacion = esES
              ? "La señal GPS aún tiene poca precisión. Intenta al aire libre o ajusta el punto en el mapa."
              : "GPS accuracy is still low. Try outdoors or adjust the point on the map.";
        }
      });
      await _getDirectionFromCoordinates(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint("Error al obtener ubicación precisa: $e");
      if (mounted) {
        setState(() {
          _mensajeUbicacion = esES
              ? "No fue posible confirmar una ubicación precisa. Vuelve a intentar o usa el mapa."
              : "An accurate location could not be confirmed. Try again or use the map.";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _obteniendoUbicacion = false);
      }
    }
  }

  Future<void> _requestLocationDisclosureAndStart() async {
    if (_locationDisclosureAccepted) {
      await _getCurrentLocation();
      return;
    }
    final bool esES = widget.idioma == "ES";
    final bool accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(esES ? "Uso de tu ubicación" : "Use of your location"),
            content: Text(
              esES
                  ? "EcoAlerta usa tu ubicación precisa únicamente cuando creas un reporte para ubicar el incidente. Las coordenadas se guardan con el reporte y pueden enviarse a la entidad responsable. No se obtiene ubicación en segundo plano."
                  : "EcoAlerta uses your precise location only while you create a report to locate the incident. Coordinates are stored with the report and may be sent to the responsible authority. Location is not collected in the background.",
            ),
            actions: [
              TextButton(
                onPressed: () => launchUrl(
                  ApiConfig.privacyPolicyUrl,
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(esES ? "Ver política" : "View policy"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(esES ? "Ahora no" : "Not now"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(esES ? "Continuar" : "Continue"),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted) return;
    if (!accepted) {
      setState(() {
        _mensajeUbicacion = esES
            ? "Puedes ubicar el incidente manualmente en el mapa o activar el GPS después."
            : "You can set the incident manually on the map or enable GPS later.";
      });
      return;
    }
    _locationDisclosureAccepted = true;
    await _getCurrentLocation();
  }

  Future<void> _seleccionarImagen(ImageSource source) async {
    try {
      if (_listaImagenes.length >= 5) {
        _mostrarMensajeCantidad();
        return;
      }
      bool agregoImagen = false;
      if (source == ImageSource.camera) {
        final XFile? photo = await _picker.pickImage(
          source: source,
          imageQuality: 70,
        );

        if (photo != null) {
          final Uint8List bytes = await photo.readAsBytes();

          if (_excedeLimiteDePeso(bytes.length)) {
            _mostrarMensajeLimite();
          } else {
            setState(() {
              _listaImagenes.add(bytes);
              aiResponse = null;
              _analysisToken = null;
            });
            agregoImagen = true;
          }
        }
      } else {
        final List<XFile> photos = await _picker.pickMultiImage(
          imageQuality: 70,
        );

        for (int i = 0; i < photos.length; i++) {
          if (_listaImagenes.length >= 5) {
            _mostrarMensajeCantidad();
            break;
          }
          final Uint8List bytes = await photos[i].readAsBytes();

          if (_excedeLimiteDePeso(bytes.length)) {
            _mostrarMensajeLimite();
            break;
          } else {
            setState(() {
              _listaImagenes.add(bytes);
              aiResponse = null;
              _analysisToken = null;
            });
            agregoImagen = true;
          }
        }
      }

      if (agregoImagen && _listaImagenes.isNotEmpty) {
        await _analyzeImagesBackground();
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _analyzeImagesBackground() async {
    if (_listaImagenes.isEmpty) return;

    final bool esES = widget.idioma == "ES";

    setState(() {
      isAnalyzing = true;
      _aiErrorMessage = null;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        ApiConfig.endpoint('/reportes/analizar-previa'),
      );

      for (int i = 0; i < _listaImagenes.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'imagenes',
            _listaImagenes[i],
            filename: 'image_$i.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded =
            jsonDecode(response.body) as Map<String, dynamic>;
        if (_isValidAiAnalysis(decoded)) {
          setState(() {
            aiResponse = decoded;
            _analysisToken = decoded['analysis_token']?.toString();
            _aiErrorMessage = null;
          });
          _applyAiColorToPriority(decoded);
        } else if (decoded['success'] == true && decoded['analisis'] != null) {
          setState(() {
            aiResponse = decoded;
            _analysisToken = decoded['analysis_token']?.toString();
            _aiErrorMessage = null;
          });
          _applyAiColorToPriority(decoded);
          debugPrint(
            'AI returned fallback analysis, allowing submission with warning.',
          );
          return;
        } else {
          final bool esES = widget.idioma == "ES";
          setState(() {
            aiResponse = null;
            _analysisToken = null;
            _aiErrorMessage = decoded['error']?.toString() ??
                (esES
                    ? 'La IA no pudo completar el análisis. Por favor intenta nuevamente con fotos más claras.'
                    : 'The AI could not complete the analysis. Please try again with clearer photos.');
          });
        }
        debugPrint('Success');
      } else {
        final bool esES = widget.idioma == "ES";
        setState(() {
          aiResponse = null;
          _analysisToken = null;
          _aiErrorMessage = esES
              ? 'No se pudo analizar la imagen. Intente de nuevo más tarde.'
              : 'Could not analyze the image. Please try again later.';
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        aiResponse = null;
        _analysisToken = null;
        _aiErrorMessage = esES
            ? 'Error de comunicación con el servicio de análisis. Revise su conexión.'
            : 'Communication error with the analysis service. Check your connection.';
      });
    } finally {
      if (mounted) setState(() => isAnalyzing = false);
    }
  }

  bool _isValidAiAnalysis(Map<String, dynamic> response) {
    if (response['analisis'] == null || response['analisis'] is! Map) {
      return false;
    }
    final analisis = response['analisis'] as Map<String, dynamic>;
    return analisis.containsKey('tipo_problema') &&
        analisis.containsKey('nivel_peligro') &&
        (analisis.containsKey('color_asignado') ||
            analisis.containsKey('color')) &&
        analisis.containsKey('entidad_destino') &&
        analisis.containsKey('valido');
  }

  void _applyAiColorToPriority(Map<String, dynamic> response) {
    final analisis = response['analisis'] as Map<String, dynamic>;
    final String colorAsignado =
        (analisis['color_asignado'] ?? analisis['color'] ?? '')
            .toString()
            .toLowerCase();
    if (colorAsignado.contains('green') || colorAsignado.contains('verde')) {
      setState(() {
        _selectedPriority = 'green';
      });
    } else if (colorAsignado.contains('yellow') ||
        colorAsignado.contains('amarillo')) {
      setState(() {
        _selectedPriority = 'yellow';
      });
    } else if (colorAsignado.contains('red') ||
        colorAsignado.contains('rojo')) {
      setState(() {
        _selectedPriority = 'red';
      });
    }
  }

  String _formatAiValue(String key) {
    if (aiResponse == null || aiResponse!['analisis'] == null) return '';
    final analisis = aiResponse!['analisis'] as Map<String, dynamic>;
    if (key == 'color_asignado') {
      return (analisis['color_asignado'] ?? analisis['color'])?.toString() ??
          '';
    }
    return analisis[key]?.toString() ?? '';
  }

  bool _excedeLimiteDePeso(int newBytes) {
    int currentTotalWeight = 0;

    for (int i = 0; i < _listaImagenes.length; i++) {
      currentTotalWeight = currentTotalWeight + _listaImagenes[i].length;
    }

    int projectedWeight = currentTotalWeight + newBytes;

    if (projectedWeight > _limiteBytes) {
      return true;
    } else {
      return false;
    }
  }

  void _mostrarMensajeLimite() {
    bool isSpanish = widget.idioma == "ES";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSpanish
              ? "No puedes exceder el límite de 7MB en fotos."
              : "You cannot exceed the 7MB photo limit.",
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _mostrarMensajeCantidad() {
    final esES = widget.idioma == "ES";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          esES
              ? "Puedes adjuntar un máximo de 5 fotografías."
              : "You can attach up to 5 photos.",
        ),
        backgroundColor: Colors.orange.shade800,
      ),
    );
  }

  void _mostrarOpcionesImagen() {
    bool esES = widget.idioma == "ES";
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: Text(
                  esES ? "Tomar Fotografía (Cámara)" : "Take Photo (Camera)",
                ),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: Text(
                  esES ? "Seleccionar desde la Galería" : "Select from Gallery",
                ),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarImagen(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirSelectorMapa() {
    bool esES = widget.idioma == "ES";

    _tempLatitude = _latitude;
    _tempLongitude = _longitude;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                esES
                    ? "Mueve el mapa para ubicar el punto"
                    : "Move the map to set the location",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.height * 0.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _dialogMapController,
                    options: MapOptions(
                      initialCenter: LatLng(_tempLatitude, _tempLongitude),
                      initialZoom: 16,
                      onTap: (tapPosition, point) {
                        setDialogState(() {
                          _tempLatitude = point.latitude;
                          _tempLongitude = point.longitude;
                        });
                      },
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          setDialogState(() {
                            _tempLatitude = position.center.latitude;
                            _tempLongitude = position.center.longitude;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ecoalerta.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_tempLatitude, _tempLongitude),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    esES ? "Cancelar" : "Cancel",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    setState(() {
                      _latitude = _tempLatitude;
                      _longitude = _tempLongitude;
                      _ubicacionConfirmada = true;
                      _precisionMetros = null;
                      _precisionReducida = false;
                      _mensajeUbicacion = esES
                          ? "Punto ajustado y confirmado manualmente."
                          : "Point manually adjusted and confirmed.";
                    });
                    Navigator.pop(context);
                    _getDirectionFromCoordinates(_latitude, _longitude);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          esES
                              ? "Punto fijado con éxito"
                              : "Point successfully set",
                        ),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    esES ? "Confirmar" : "Confirm",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
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

  String _priorityDescription() {
    switch (_selectedPriority) {
      case "green":
        return widget.idioma == "ES"
            ? "Moderado: Basura acumulada, ruido o situaciones sin riesgo inmediato."
            : "Moderate: Garbage accumulation or issues without immediate danger.";
      case "yellow":
        return widget.idioma == "ES"
            ? "Atención rápida: Fugas de agua  o riesgos potenciales."
            : "Quick attention: Water leaks or potential risks.";
      case "red":
        return widget.idioma == "ES"
            ? "Urgente: Derrames químicos, incendios o peligro inminente."
            : "Urgent: Chemical spills, fires or imminent danger.";
      default:
        return "";
    }
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
          esES ? "Crear Nuevo Reporte" : "Create New Report",
          style: _estiloConRelieve(
            fontSize: 20,
            isBold: true,
            color: Colors.white,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText:
                      esES ? "Descripción del problema" : "Problem Description",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  fillColor: Colors.white,
                  filled: true,
                  suffixIcon: _obteniendoDireccion
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.green,
                            ),
                          ),
                        )
                      : const Icon(Icons.location_on, color: Colors.green),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return esES
                        ? "Ingrese una descripción"
                        : "Enter a description";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: esES
                            ? "Dirección del hecho (Opcional)"
                            : "Incident Address (Optional)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        prefixIcon: const Icon(
                          Icons.directions,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.map, size: 16),
                        label: Text(
                          esES ? "Ubicar punto" : "Set point",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _abrirSelectorMapa,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  "Lat: ${_latitude.toStringAsFixed(5)}  |  Lon: ${_longitude.toStringAsFixed(5)}",
                  style: _estiloConRelieve(
                    fontSize: 11,
                    isBold: false,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _ubicacionConfirmada
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _ubicacionConfirmada
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _ubicacionConfirmada
                              ? Icons.gps_fixed
                              : Icons.gps_not_fixed,
                          color: _ubicacionConfirmada
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _precisionMetros == null
                                ? (_mensajeUbicacion ??
                                    (esES
                                        ? "Ubicación pendiente de confirmación."
                                        : "Location confirmation pending."))
                                : "${_mensajeUbicacion ?? ''} ${esES ? 'Precisión' : 'Accuracy'}: ±${_precisionMetros!.round()} m",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _obteniendoUbicacion
                              ? null
                              : _requestLocationDisclosureAndStart,
                          icon: _obteniendoUbicacion
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 18),
                          label: Text(
                            esES ? "Actualizar GPS" : "Refresh GPS",
                          ),
                        ),
                        if (_precisionReducida)
                          TextButton.icon(
                            onPressed: Geolocator.openAppSettings,
                            icon: const Icon(Icons.settings, size: 18),
                            label: Text(
                              esES
                                  ? "Activar ubicación precisa"
                                  : "Enable precise location",
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Text(
                esES ? "Nivel de prioridad:" : "Priority level:",
                style: _estiloConRelieve(fontSize: 14, isBold: true),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _priorityButton("green", Colors.green, Icons.eco),
                  _priorityButton("yellow", Colors.amber, Icons.warning),
                  _priorityButton("red", Colors.red, Icons.report_problem),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                _priorityDescription(),
                style: _estiloConRelieve(
                  fontSize: 12,
                  isBold: false,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 15),

              // SECCIÓN DE EVIDENCIA FOTOGRÁFICA
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    esES ? "Evidencia Fotográfica" : "Photographic Evidence",
                    style: _estiloConRelieve(fontSize: 14, isBold: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_a_photo, color: Colors.green),
                    onPressed: _mostrarOpcionesImagen,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: _listaImagenes.isNotEmpty
                    ? ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _listaImagenes.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    _listaImagenes[index],
                                    fit: BoxFit.cover,
                                    width: 140,
                                    height: 140,
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _listaImagenes.removeAt(index);
                                        aiResponse = null;
                                        _analysisToken = null;
                                        _aiErrorMessage = null;
                                      });
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Text(
                          esES
                              ? "No hay fotos. Presiona el ícono superior para agregar."
                              : "No photos. Tap the top icon to add.",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              if (isAnalyzing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          esES
                              ? 'Analizando imágenes para determinar tipo de problema, nivel de peligro, color y entidad responsable...'
                              : 'Analyzing images to determine problem type, danger level, color and responsible entity...',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_aiErrorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _aiErrorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              if (aiResponse != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esES ? 'Resumen IA' : 'AI Summary',
                        style: _estiloConRelieve(fontSize: 14, isBold: true),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${esES ? 'Problema' : 'Problem'}: ${_formatAiValue('tipo_problema')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${esES ? 'Peligro' : 'Danger Level'}: ${_formatAiValue('nivel_peligro')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${esES ? 'Color asignado' : 'Assigned color'}: ${_formatAiValue('color_asignado')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${esES ? 'Entidad asignada' : 'Assigned entity'}: ${_formatAiValue('entidad_destino')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${esES ? 'Justificación' : 'Justification'}: ${_formatAiValue('justificacion')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _aceptaDatos,
                onChanged: (value) {
                  setState(() {
                    _aceptaDatos = value ?? false;
                  });
                },
                title: Text(
                  esES
                      ? "Acepto el tratamiento de datos según la Ley 1581 de 2012 de Colombia."
                      : "I accept data processing under Colombia Law 1581 of 2012.",
                  style: _estiloConRelieve(fontSize: 12, isBold: false),
                ),
              ),
              const SizedBox(height: 10),
              if (!isAnalyzing &&
                  _listaImagenes.isNotEmpty &&
                  aiResponse == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    esES
                        ? 'No se ha completado el análisis de IA. Espera un momento antes de enviar el reporte.'
                        : 'The AI analysis is not complete yet. Please wait a moment before sending the report.',
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: !_canSendReport
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegisterScreen(
                                  idioma: widget.idioma,
                                  descripcion: _descriptionController.text,
                                  direccionReporte: _addressController.text,
                                  latitud: _latitude,
                                  longitud: _longitude,
                                  listaImagenesBytes: _listaImagenes,
                                  radicadoOriginal: '',
                                  analysisToken: _analysisToken ?? '',
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    esES
                        ? "Finalizar y Enviar Reporte"
                        : "Finish & Submit Report",
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
      ),
    );
  }

  Widget _priorityButton(
    String value,
    Color color,
    IconData iconoSeleccionado,
  ) {
    bool selected = _selectedPriority == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPriority = value;
        });
      },
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
          border: selected ? Border.all(color: Colors.black, width: 3) : null,
        ),
        child: Icon(
          iconoSeleccionado,
          color: Colors.white,
          size: selected ? 30 : 24,
        ),
      ),
    );
  }
}

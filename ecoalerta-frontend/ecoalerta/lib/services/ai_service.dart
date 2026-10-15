import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';

class AIService {
  static bool _hasRequiredAnalysisFields(Map<String, dynamic> response) {
    if (response['analisis'] is! Map) return false;
    final analisis = response['analisis'] as Map;
    return analisis.containsKey('tipo_problema') &&
        analisis.containsKey('nivel_peligro') &&
        (analisis.containsKey('color_asignado') || analisis.containsKey('color')) &&
        analisis.containsKey('prioridad') &&
        analisis.containsKey('entidad_destino') &&
        analisis.containsKey('valido') &&
        analisis.containsKey('descripcion_ia') &&
        analisis.containsKey('justificacion') &&
        analisis.containsKey('evaluacion_riesgo');
  }

  static Future<Map<String, dynamic>> enviarYClasificarReporte({
    required String descripcion,
    required String direccion,
    required double latitud,
    required double longitud,
    required List<Uint8List> imagenes,
    required String correoUsuario,
    String nombreUsuario = '',
    String direccionUsuario = '',
    String radicadoOriginal = '',
    String origen = 'app',
    String analysisToken = '',
  }) async {
    try {
      final request = http.MultipartRequest('POST', ApiConfig.endpoint('/reportes'));
      request.fields.addAll({
        'descripcion': descripcion,
        'direccion': direccion,
        'latitud': latitud.toString(),
        'longitud': longitud.toString(),
        'correo_usuario': correoUsuario.trim(),
        'nombre_usuario': nombreUsuario.trim(),
        'direccion_usuario': direccionUsuario.trim(),
        'consentimiento_datos': 'true',
        'radicado_original': radicadoOriginal,
        'origen': origen,
        'analysis_token': analysisToken,
      });

      for (int i = 0; i < imagenes.length; i++) {
        if (imagenes[i].isEmpty) continue;
        request.files.add(http.MultipartFile.fromBytes(
          'imagenes',
          imagenes[i],
          filename: 'evidencia_$i.jpg',
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      Map<String, dynamic> decoded = {};
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'success': false, 'error': 'El servidor devolvió una respuesta no válida.'};
      }

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          decoded['success'] == true &&
          _hasRequiredAnalysisFields(decoded)) {
        return decoded;
      }
      return {
        'success': false,
        'error': decoded['detail']?.toString() ??
            decoded['error']?.toString() ??
            'No fue posible registrar el reporte.',
      };
    } on TimeoutException {
      return {'success': false, 'error': 'La solicitud tardó demasiado. Verifica tu conexión e intenta de nuevo.'};
    } catch (_) {
      return {'success': false, 'error': 'No fue posible conectar con EcoAlerta. Verifica tu conexión.'};
    }
  }
}

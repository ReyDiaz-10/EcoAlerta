import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class ReporteService {
  final Dio _dio = Dio();

  Future<void> enviarReporteSocioambiental({
    required String descripcion,
    required String direccion,
    required double latitud,
    required double longitud,
    required String correoUsuario,
    required File fotoArchivo,
  }) async {
    try {
      String url = ApiConfig.endpoint('/reportes').toString();

      // Crear el formulario FormData para envío multimedia (Multi-part)
      FormData formData = FormData.fromMap({
        "descripcion": descripcion,
        "direccion": direccion,
        "latitud": latitud,
        "longitud": longitud,
        "correo_usuario": correoUsuario,
        // Adjuntar la fotografía real tomada con la cámara
        "imagenes": await MultipartFile.fromFile(
          fotoArchivo.path,
          filename: fotoArchivo.path.split('/').last,
        ),
      });

      debugPrint("Enviando reporte a EcoAlerta");

      // Realizar la petición POST
      Response response = await _dio.post(
        url,
        data: formData,
        options: Options(
          headers: {
            "Accept": "application/json",
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Reporte enviado con éxito");
        // Aquí puedes retornar response.data si necesitas el Radicado en tu UI
      }
    } on DioException catch (e) {
      debugPrint("Error de red al enviar reporte: ${e.message}");
      if (e.response != null) {
        debugPrint("El servidor rechazó la solicitud");
      }
      rethrow;
    } catch (e) {
      debugPrint("Error inesperado al enviar reporte");
      rethrow;
    }
  }
}

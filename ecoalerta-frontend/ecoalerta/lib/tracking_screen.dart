import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'config/api_config.dart';

class TrackingScreen extends StatefulWidget {
  final String idioma;

  const TrackingScreen({super.key, required this.idioma});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _radicado = TextEditingController();
  final _codigo = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _report;

  @override
  void dispose() {
    _radicado.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    final filing = _radicado.text.trim().toUpperCase();
    final code = _codigo.text.trim();
    final esES = widget.idioma == 'ES';
    if (!RegExp(r'^RAD-[A-Z0-9-]{5,40}$').hasMatch(filing) || code.length < 10) {
      setState(() => _error = esES
          ? 'Ingresa el radicado y el código de consulta válidos.'
          : 'Enter a valid filing number and lookup code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final uri = ApiConfig.endpoint('/reportes/consulta').replace(
        queryParameters: {'radicado': filing, 'codigo': code},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (response.statusCode == 200 && data['reporte'] is Map) {
        setState(() => _report = Map<String, dynamic>.from(data['reporte'] as Map));
      } else {
        setState(() => _error = data['detail']?.toString() ??
            (esES ? 'No se encontró el reporte.' : 'Report not found.'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = esES
            ? 'No fue posible conectar con EcoAlerta.'
            : 'Could not connect to EcoAlerta.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _descargar() async {
    final uri = ApiConfig.endpoint(
      '/reportes/${Uri.encodeComponent(_radicado.text.trim().toUpperCase())}/download',
    ).replace(queryParameters: {'codigo': _codigo.text.trim()});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final esES = widget.idioma == 'ES';
    return Scaffold(
      appBar: AppBar(title: Text(esES ? 'Consultar reporte' : 'Track report')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            esES
                ? 'Usa los dos datos entregados al finalizar tu reporte.'
                : 'Use the two details provided after submitting your report.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _radicado,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: esES ? 'Radicado' : 'Filing number'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codigo,
            obscureText: true,
            decoration: InputDecoration(labelText: esES ? 'Código de consulta' : 'Lookup code'),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _loading ? null : _consultar,
            icon: const Icon(Icons.search),
            label: Text(esES ? 'Consultar' : 'Search'),
          ),
          if (_loading) const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
          if (_report != null) Card(
            margin: const EdgeInsets.only(top: 20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _report!['radicado']?.toString() ?? '',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${esES ? 'Estado' : 'Status'}: ${_report!['estado'] ?? 'RECIBIDO'}'),
                  Text('${esES ? 'Entidad' : 'Entity'}: ${_report!['entidad_assigned'] ?? ''}'),
                  Text('${esES ? 'Categoría' : 'Category'}: ${_report!['categoria'] ?? ''}'),
                  Text('${esES ? 'Prioridad' : 'Priority'}: ${_report!['nivel_peligro'] ?? ''}'),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _descargar,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(esES ? 'Abrir PDF' : 'Open PDF'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config/api_config.dart';
import 'admin_login_screen.dart';
import 'services/admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _metrics;
  List<dynamic> _reports = [];
  List<dynamic> _filteredReports = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedColor = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadDashboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _filteredReports = _reports.where((report) {
        final radicado = report['radicado']?.toString().toLowerCase() ?? '';
        final search = _searchController.text.toLowerCase();
        final color = report['color']?.toString().toLowerCase() ?? '';
        final entidad = report['entidad_assigned']?.toString().toLowerCase() ??
            report['entidad_destino']?.toString().toLowerCase() ??
            '';
        final direccion =
            report['direccion_declarada']?.toString().toLowerCase() ??
                report['direccion']?.toString().toLowerCase() ??
                '';

        final matchesSearch = search.isEmpty ||
            radicado.contains(search) ||
            entidad.contains(search) ||
            direccion.contains(search);
        final matchesColor =
            _selectedColor.isEmpty || color.contains(_selectedColor);

        return matchesSearch && matchesColor;
      }).toList();
    });
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final metricResult = await AdminService.fetchMetrics();
    final reportsResult = await AdminService.fetchReports();

    if (!mounted) return;

    if (metricResult['success'] != true) {
      setState(() {
        _loading = false;
        _errorMessage =
            metricResult['error']?.toString() ?? 'Error al cargar métricas';
      });
      return;
    }

    if (reportsResult['success'] != true) {
      setState(() {
        _loading = false;
        _errorMessage =
            reportsResult['error']?.toString() ?? 'Error al cargar reportes';
      });
      return;
    }

    setState(() {
      _loading = false;
      _metrics = metricResult['metrics'] as Map<String, dynamic>?;
      _reports = reportsResult['reports'] as List<dynamic>? ?? [];
      _filteredReports = _reports;
    });
  }

  void _logout() {
    AdminService.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
    );
  }

  Future<void> _openFullAdminPanel() async {
    final uri = Uri.parse('${ApiConfig.publicBaseUrl}/portal/admin.html');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible abrir el panel administrativo web.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        title: const Text('Dashboard Admin'),
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  const Text(
                    'Métricas de EcoAlerta',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Desliza esta pantalla para consultar todos los reportes.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openFullAdminPanel,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text(
                        'Abrir panel administrativo completo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_metrics != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildMetricCard('Total', _metrics!['total_reportes']?.toString() ?? '0', cardWidth),
                            _buildMetricCard('Verde', _metrics!['color_green']?.toString() ?? '0', cardWidth),
                            _buildMetricCard('Amarillo', _metrics!['color_yellow']?.toString() ?? '0', cardWidth),
                            _buildMetricCard('Rojo', _metrics!['color_red']?.toString() ?? '0', cardWidth),
                            _buildMetricCard('Enviados', _metrics!['email_enviados']?.toString() ?? '0', cardWidth),
                            _buildMetricCard('Fallidos', _metrics!['email_fallidos']?.toString() ?? '0', cardWidth),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Búsqueda y filtros',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar por radicado, entidad o dirección',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedColor.isEmpty ? null : _selectedColor,
                          hint: const Text('Filtrar por color'),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('Todos')),
                            DropdownMenuItem(
                              value: 'green',
                              child: Text('Verde'),
                            ),
                            DropdownMenuItem(
                              value: 'yellow',
                              child: Text('Amarillo'),
                            ),
                            DropdownMenuItem(value: 'red', child: Text('Rojo')),
                          ],
                          onChanged: (value) {
                            _selectedColor = value ?? '';
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _applyFilters,
                        child: const Text('Aplicar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Reportes (${_filteredReports.length} resultados)',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_filteredReports.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          _errorMessage ?? 'No hay reportes disponibles.',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    )
                  else
                    ..._filteredReports.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildReportCard(item as Map<String, dynamic>),
                      ),
                    ),
                  const SafeArea(top: false, child: SizedBox(height: 12)),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final colorName = report['color']?.toString().toLowerCase() ?? '';
    final alertColor = switch (colorName) {
      'red' => const Color(0xFFD6453D),
      'yellow' => const Color(0xFFE0A11A),
      'green' => const Color(0xFF2E9D55),
      _ => Colors.blueGrey,
    };
    final alertLabel = switch (colorName) {
      'red' => 'Alta',
      'yellow' => 'Media',
      'green' => 'Baja',
      _ => 'Sin nivel',
    };
    final entity = report['entidad_assigned'] ?? report['entidad_destino'] ?? 'Sin entidad';
    final address = report['direccion_declarada'] ?? report['direccion'] ?? 'Sin dirección';

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: alertColor.withValues(alpha: 0.45), width: 1.4),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _showReportDetail(report),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 7, color: alertColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              report['radicado']?.toString() ?? 'Sin radicado',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: alertColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(alertLabel, style: TextStyle(color: alertColor, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(entity.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(address.toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 9),
                      Text('Toca para ver todos los detalles', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReportDetail(Map<String, dynamic> report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text(report['radicado']?.toString() ?? 'Detalle', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            _detailLine('Estado', report['estado']),
            _detailLine('Categoría', report['tipo_problema'] ?? report['subcategoria'] ?? report['categoria']),
            _detailLine('Entidad', report['entidad_assigned'] ?? report['entidad_destino']),
            _detailLine('Dirección', report['direccion_declarada'] ?? report['direccion']),
            _detailLine('Descripción ciudadana', report['descripcion_ciudadano'] ?? report['descripcion']),
            _detailLine('Evaluación de riesgo', report['evaluacion_riesgo']),
            _detailLine('Descripción IA', report['descripcion_ia']),
            _detailLine('Correo', report['email_enviado'] == true ? 'Entregado' : 'No entregado'),
            _detailLine('Intentos de correo', report['email_intentos'] ?? 0),
            if (report['email_error'] != null && report['email_error'].toString().isNotEmpty)
              _detailLine('Error de correo', report['email_error']),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(String label, Object? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value?.toString().trim().isNotEmpty == true ? value.toString() : 'No disponible'),
        ],
      ),
    );
  }
}

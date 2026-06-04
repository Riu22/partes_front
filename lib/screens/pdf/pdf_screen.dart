/// Pantalla para exportar informes de partes en PDF o ZIP.
/// Permite seleccionar rango de fechas, obras, operarios y el formato
/// de exportación (PDF único, ZIP por obra o ZIP por operario).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/pdf_export_params.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/perfiles_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fecha_tile.dart' show RangoFechaTile;
import '../../widgets/modo_tile.dart';
import '../../widgets/obras_selector.dart';
import '../../widgets/perfiles_selector.dart';
import '../../widgets/export_preview.dart';
import '../../providers/obras_provider.dart';


/// Pantalla de generación de informes de partes. Permite seleccionar
/// filtros (fechas, obras, operarios) y elegir formato de exportación
/// (PDF único, ZIP por obra o ZIP por operario).
class InformePartesScreen extends ConsumerStatefulWidget {
  const InformePartesScreen({super.key});

  @override
  ConsumerState<InformePartesScreen> createState() =>
      _InformePartesScreenState();
}

/// Gestiona los filtros (fechas, obras, operarios, modo) y genera
/// la previsualización/exportación del informe de partes.
class _InformePartesScreenState extends ConsumerState<InformePartesScreen> {
  DateTime _desde = DateTime.now().subtract(const Duration(days: 15));
  DateTime _hasta = DateTime.now();

  final Set<int> _obrasSeleccionadas = {};
  final Set<String> _perfilesSeleccionados = {};

  ModoExport _modo = ModoExport.zip;

  PdfParams? _params;

  void _onRangoChanged(DateTimeRange rango) {
    setState(() {
      _desde = rango.start;
      _hasta = rango.end;
      _params = null;
    });
  }

  void _generarInforme() {
    final params = PdfParams(
      desde: _desde,
      hasta: _hasta,
      obraIds: _obrasSeleccionadas.toList(),
      perfilIds: _perfilesSeleccionados.toList(),
      modo: _modo,
    );
    ref.invalidate(exportProvider(params));
    setState(() {
      _params = params;
    });
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(authProvider).valueOrNull;
    final esJefe = perfil?.esJefeObra == true &&
        perfil?.esAdmin != true &&
        perfil?.esGestion != true;

    // Los jefes ven solo sus obras asignadas; admin/gestión ven todas
    final obrasAsync =
        esJefe ? ref.watch(misObrasProvider) : ref.watch(obrasProvider);
    final perfilesAsync = ref.watch(perfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Informe de partes')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rango de fechas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  RangoFechaTile(
                    desde: _desde,
                    hasta: _hasta,
                    onChanged: _onRangoChanged,
                  ),
                  const SizedBox(height: 20),
                  obrasAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (obras) => ObrasSelector(
                      obras: obras,
                      seleccionadas: _obrasSeleccionadas,
                      onChanged: (ids) {
                        setState(() {
                          _obrasSeleccionadas
                            ..clear()
                            ..addAll(ids);
                          _params = null;
                        });
                      },
                    ),
                  ),
                  if (!esJefe) ...[
                    const SizedBox(height: 20),
                    perfilesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (perfiles) => PerfilesSelector(
                        perfiles: perfiles.where((p) => p.activo).toList(),
                        seleccionados: _perfilesSeleccionados,
                        onChanged: (ids) {
                          setState(() {
                            _perfilesSeleccionados
                              ..clear()
                              ..addAll(ids);
                            _params = null;
                          });
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Formato de exportación',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ModoTile(
                          label: 'ZIP por obra',
                          subtitulo: 'Un PDF por obra',
                          icono: Icons.folder_zip,
                          seleccionado: _modo == ModoExport.zip,
                          onTap: () {
                            setState(() {
                              _modo = ModoExport.zip;
                              _params = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ModoTile(
                          label: 'PDF único',
                          subtitulo: 'Todas las obras en un archivo',
                          icono: Icons.picture_as_pdf,
                          seleccionado: _modo == ModoExport.pdf,
                          onTap: () {
                            setState(() {
                              _modo = ModoExport.pdf;
                              _params = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ModoTile(
                    label: 'ZIP por operario',
                    subtitulo: 'Un PDF por operario con todas sus obras',
                    icono: Icons.people,
                    seleccionado: _modo == ModoExport.zipOperario,
                    onTap: () {
                      setState(() {
                        _modo = ModoExport.zipOperario;
                        _params = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _generarInforme,
                      icon: Icon(
                        (_modo == ModoExport.zip ||
                                _modo == ModoExport.zipOperario)
                            ? Icons.folder_zip
                            : Icons.picture_as_pdf,
                      ),
                      label: Text(
                        (_modo == ModoExport.zip ||
                                _modo == ModoExport.zipOperario)
                            ? 'Generar ZIP'
                            : 'Generar PDF',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (_params != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    ExportPreview(params: _params!),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
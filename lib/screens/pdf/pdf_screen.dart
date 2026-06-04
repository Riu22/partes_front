// =============================================================================
// pdf_screen.dart
// =============================================================================
// QUE ES:       Pantalla de generacion de informes de partes en PDF/ZIP.
// PARA QUE:     Seleccionar filtros (fechas, obras, operarios) y formato de
//               exportacion (PDF unico, ZIP por obra, ZIP por operario).
// QUIEN LO USA: Administradores, gestion, jefes de obra.
// COMO SE LLEGA: Desde el AppDrawer.
// A DONDE VA:   GET /api/exportar-partes (servidor) - genera PDF/ZIP.
// QUE DATOS USA: auth_provider, admin_provider, perfiles_provider,
//                obras_provider, pdf_export_params, widgets varios.
// OFFLINE:      No aplica.
// =============================================================================

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

/// Pantalla de generacion de informes de partes. Permite seleccionar
/// filtros (fechas, obras, operarios) y elegir formato de exportacion
/// (PDF unico, ZIP por obra o ZIP por operario).
class InformePartesScreen extends ConsumerStatefulWidget {
  const InformePartesScreen({super.key});

  @override
  ConsumerState<InformePartesScreen> createState() =>
      _InformePartesScreenState();
}

/// Gestiona los filtros (fechas, obras, operarios, modo) y genera
/// la previsualizacion/exportacion del informe de partes.
class _InformePartesScreenState extends ConsumerState<InformePartesScreen> {
  // -- Fechas (default: ultimos 15 dias) --
  DateTime _desde = DateTime.now().subtract(const Duration(days: 15));
  DateTime _hasta = DateTime.now();

  // -- Selecciones --
  final Set<int> _obrasSeleccionadas = {};
  final Set<String> _perfilesSeleccionados = {};

  // -- Modo de exportacion --
  ModoExport _modo = ModoExport.zip;

  // -- Parametros para preview --
  PdfParams? _params;

  /// Callback cuando cambia el rango de fechas.
  void _onRangoChanged(DateTimeRange rango) {
    setState(() {
      _desde = rango.start;
      _hasta = rango.end;
      _params = null; // Invalida la preview anterior
    });
  }

  /// Genera el informe con los filtros actuales.
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
    // Los jefes de obra solo ven sus obras asignadas
    final esJefe = perfil?.esJefeObra == true &&
        perfil?.esAdmin != true &&
        perfil?.esGestion != true;

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
                  // ---- Rango de fechas ----
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

                  // ---- Selector de obras ----
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

                  // ---- Selector de operarios (solo no jefes) ----
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

                  // ---- Formato de exportacion ----
                  const Text(
                    'Formato de exportacion',
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
                          label: 'PDF unico',
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

                  // ZIP por operario
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

                  // ---- Boton de generacion ----
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

                  // ---- Preview de exportacion ----
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

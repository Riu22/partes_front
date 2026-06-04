// =============================================================================
// export_preview.dart  -  Vista previa de exportacion a PDF/ZIP
// =============================================================================
// ASPECTO EN PANTALLA:
//   Recuadro verde claro con borde verde. Muestra icono (PDF o ZIP),
//   nombre del archivo, tamano en KB, y boton azul "Descargar".
//   Si es ZIP, anade texto explicativo: "El ZIP contiene un PDF por obra/u
//   operario". Mientras se genera: spinner de carga centrado. Si hay error:
//   mensaje en rojo.
//
// USO:
//   Pantalla de exportacion de partes. El usuario selecciona parametros
//   (rango de fechas, obras, operarios, modo) y esta vista previa genera
//   el archivo y permite descargarlo.
//
// DATOS QUE NECESITA:
//   - params: PdfParams con desde, hasta, obraIds, perfilIds, modo
//     (pdf, zip, zipOperario)
//   - exportProvider: FutureProvider.family que genera los bytes del archivo
//   - apiServiceProvider: para guardar el archivo localmente
//
// INTERACCION DEL USUARIO:
//   - Tocar "Descargar": guarda el archivo y muestra SnackBar
//   - Mientras se genera: spinner de carga
//   - Si hay error: mensaje de error
// =============================================================================

/// Vista previa de la exportación de partes a PDF o ZIP.
/// Muestra el tamaño del archivo generado y un botón para descargarlo.
/// Soporta exportación normal (PDF), ZIP por obra y ZIP por operario.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/pdf_export_params.dart';
import '../providers/auth_provider.dart';

/// [FutureProvider.family] que genera los bytes del archivo (PDF o ZIP).
///
/// Toma [PdfParams] como argumento de la familia. Se invalida solo cuando
/// los parametros cambian. Usa [apiServiceProvider] para hacer la llamada
/// HTTP al backend que genera el archivo.
///
/// [FutureProvider] es un provider de Riverpod para operaciones asincronas.
/// .family permite parametrizarlo (en este caso por los filtros).
final exportProvider =
    FutureProvider.family<Uint8List, PdfParams>((ref, params) async {
  if (params.modo == ModoExport.zip) {
    return ref
        .read(apiServiceProvider)
        .generarZipPartes(
          desde: params.desde,
          hasta: params.hasta,
          obraIds: params.obraIds,
          perfilIds: params.perfilIds,
        );
  } else if (params.modo == ModoExport.zipOperario) {
    return ref
        .read(apiServiceProvider)
        .generarZipPartesPorOperario(
          desde: params.desde,
          hasta: params.hasta,
          obraIds: params.obraIds,
          perfilIds: params.perfilIds,
        );
  } else {
    // Modo por defecto: PDF normal.
    return ref
        .read(apiServiceProvider)
        .generarPdfPartes(
          desde: params.desde,
          hasta: params.hasta,
          obraIds: params.obraIds,
          perfilIds: params.perfilIds,
        );
  }
});

/// Widget que muestra la vista previa del archivo generado y permite
/// descargarlo. [ConsumerWidget] para acceder a providers.
class ExportPreview extends ConsumerWidget {
  final PdfParams params;

  const ExportPreview({super.key, required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escucha el provider que genera el archivo. Se reconstruye cuando
    // cambia el estado (loading, error, data).
    final async = ref.watch(exportProvider(params));

    return async.when(
      // ── ESTADO DE CARGA ─────────────────────────────────
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),

      // ── ESTADO DE ERROR ─────────────────────────────────
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),

      // ── DATOS CARGADOS ──────────────────────────────────
      data: (bytes) {
        final esZip = params.modo == ModoExport.zip;
        final esZipOp = params.modo == ModoExport.zipOperario;

        // Calcula tamano en KB con un decimal.
        final kb = (bytes.length / 1024).toStringAsFixed(1);

        // Formatea fechas para el nombre del archivo.
        final desde = DateFormat('yyyy-MM-dd').format(params.desde);
        final hasta = DateFormat('yyyy-MM-dd').format(params.hasta);

        // Nombre del archivo segun el modo.
        final nombre = esZipOp
            ? 'partes_por_operario_${desde}_$hasta.zip'
            : esZip
            ? 'partes_${desde}_$hasta.zip'
            : 'partes_${desde}_$hasta.pdf';

        return Container(
          // Contenedor verde claro con borde verde.
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── FILA: icono + info + boton descargar ─────
              Row(
                children: [
                  // Icono: ZIP (carpeta) o PDF.
                  Icon(
                    esZip || esZipOp
                        ? Icons.folder_zip
                        : Icons.picture_as_pdf,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${esZipOp
                          ? 'ZIP por operario'
                          : esZip
                          ? 'ZIP por obra'
                          : 'PDF'} generado -- $kb KB',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Boton azul de descarga.
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      // Guarda el archivo en el dispositivo local.
                      ref
                          .read(apiServiceProvider)
                          .guardarPdfLocal(bytes, nombre);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Descargando $nombre...')),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Descargar'),
                  ),
                ],
              ),

              // ── TEXTO EXPLICATIVO PARA ZIP ───────────────
              if (esZip) ...[
                const SizedBox(height: 8),
                Text(
                  'El ZIP contiene un PDF por obra.',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ],
              if (esZipOp) ...[
                const SizedBox(height: 8),
                Text(
                  'El ZIP contiene un PDF por operario.',
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

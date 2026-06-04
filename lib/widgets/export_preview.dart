/// Vista previa de la exportación de partes a PDF o ZIP.
/// Muestra el tamaño del archivo generado y un botón para descargarlo.
/// Soporta exportación normal (PDF), ZIP por obra y ZIP por operario.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/pdf_export_params.dart';
import '../providers/auth_provider.dart';

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

class ExportPreview extends ConsumerWidget {
  final PdfParams params;

  const ExportPreview({super.key, required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exportProvider(params));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (bytes) {
        final esZip = params.modo == ModoExport.zip;
        final esZipOp = params.modo == ModoExport.zipOperario;
        final kb = (bytes.length / 1024).toStringAsFixed(1);
        final desde = DateFormat('yyyy-MM-dd').format(params.desde);
        final hasta = DateFormat('yyyy-MM-dd').format(params.hasta);
        final nombre = esZipOp
            ? 'partes_por_operario_${desde}_$hasta.zip'
            : esZip
            ? 'partes_${desde}_$hasta.zip'
            : 'partes_${desde}_$hasta.pdf';

        return Container(
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                          : 'PDF'} generado — $kb KB',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
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

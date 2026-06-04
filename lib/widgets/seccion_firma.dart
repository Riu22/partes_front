// =============================================================================
// seccion_firma.dart  -  Seccion de captura de firma del cliente
// =============================================================================
// ASPECTO EN PANTALLA:
//   Titulo "Firma del cliente" con badge "OPCIONAL", texto explicativo,
//   campo "Nombre del firmante (opcional)" con icono de persona, campo
//   "Trabajos extra" (textarea opcional de 3 lineas), y un boton grande
//   "Tocar para firmar" que abre un modal.
//   Cuando ya se firmo: recuadro verde con check, texto "Firma capturada
//   correctamente" y boton "Borrar".
//   Modal de firma: fondo blanco, handle, titulo "Firma del cliente",
//   canvas para dibujar con el dedo, botones "Limpiar" y "Confirmar".
//
// USO:
//   Capturar la firma del cliente al crear/editar un parte de trabajo.
//   La firma se convierte a base64 (PNG) y se envia al servidor.
//
// DATOS QUE NECESITA:
//   - onFirmaChanged: callback (base64, nombreFirma)
//   - onTrabajosExtraChanged: callback opcional para texto extra
//
// INTERACCION DEL USUARIO:
//   - Escribir nombre del firmante
//   - Escribir trabajos extra (si disponible)
//   - Tocar "Tocar para firmar" abre modal con pad de firma
//   - En el modal, dibujar con el dedo, limpiar o confirmar
//   - Confirmar guarda la firma como base64 y cierra el modal
//   - "Borrar" elimina la firma capturada
// =============================================================================

/// Sección para capturar la firma del cliente en un parte.
/// Incluye campos para el nombre del firmante, trabajos extra opcionales
/// y un pad de firma donde el cliente dibuja su firma con el dedo.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// Widget principal de la sección de firma.
/// Permite escribir nombre, trabajos extra y abrir el modal para firmar.
///
/// [StatefulWidget] porque gestiona el estado de la firma (_firmado,
/// _firmaBase64) y los controladores de texto.
class SeccionFirma extends StatefulWidget {
  final void Function(String? base64, String? nombreFirma) onFirmaChanged;
  final void Function(String trabajosExtra)? onTrabajosExtraChanged;

  const SeccionFirma({
    super.key,
    required this.onFirmaChanged,
    this.onTrabajosExtraChanged,
  });

  @override
  State<SeccionFirma> createState() => _SeccionFirmaState();
}

class _SeccionFirmaState extends State<SeccionFirma> {
  final _nombreCtrl = TextEditingController();
  final _trabajosExtraCtrl = TextEditingController();
  bool _firmado = false;
  String? _firmaBase64;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _trabajosExtraCtrl.dispose();
    super.dispose();
  }

  /// Limpia la firma capturada y notifica al padre.
  void _limpiarFirma() {
    setState(() {
      _firmado = false;
      _firmaBase64 = null;
    });
    widget.onFirmaChanged(null, null);
  }

  /// Abre el modal de firma y espera el resultado (base64).
  /// Si hay resultado, lo guarda y notifica al padre.
  Future<void> _abrirModalFirma() async {
    final resultado = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ModalFirma(),
    );

    if (resultado != null) {
      final nombre = _nombreCtrl.text.trim().isEmpty
          ? null
          : _nombreCtrl.text.trim();
      setState(() {
        _firmado = true;
        _firmaBase64 = resultado;
      });
      widget.onFirmaChanged(resultado, nombre);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firma guardada'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TITULO ───────────────────────────────────────────
        Row(
          children: [
            const Text(
              'Firma del cliente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            // Badge "OPCIONAL".
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'OPCIONAL',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'El cliente puede firmar aqui para confirmar la realizacion del trabajo',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // ── NOMBRE DEL FIRMANTE ──────────────────────────────
        TextField(
          controller: _nombreCtrl,
          decoration: InputDecoration(
            hintText: 'Nombre del firmante (opcional)',
            prefixIcon: const Icon(Icons.person_outline, size: 18),
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: _nombreCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _nombreCtrl.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // ── TRABAJOS EXTRA ───────────────────────────────────
        // Solo visible si el callback esta definido.
        if (widget.onTrabajosExtraChanged != null) ...[
          const Text(
            'Trabajos extra',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Anota cualquier trabajo adicional no previsto',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          // Textarea de 3 lineas para trabajos extra.
          TextField(
            controller: _trabajosExtraCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej: cambio de valvula no incluida en presupuesto...',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => widget.onTrabajosExtraChanged!(v),
          ),
          const SizedBox(height: 12),
        ],

        // ── PAD DE FIRMA / ESTADO ────────────────────────────
        if (_firmado && _firmaBase64 != null) ...[
          // Estado: firma capturada correctamente.
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green.shade400),
              borderRadius: BorderRadius.circular(8),
              color: Colors.green.shade50,
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Firma capturada correctamente',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: _limpiarFirma,
                  child: const Text('Borrar'),
                ),
              ],
            ),
          ),
        ] else ...[
          // Boton para abrir el modal de firma.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Tocar para firmar'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade400),
                foregroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _abrirModalFirma,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Se abrira una ventana para firmar sin interrupciones',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ],
    );
  }
}

// ── MODAL DE FIRMA ───────────────────────────────────────────────────────────

/// Modal que contiene el pad de firma donde el usuario dibuja con el dedo.
/// Usa el paquete [Signature] para capturar el trazo.
class _ModalFirma extends StatefulWidget {
  const _ModalFirma();

  @override
  State<_ModalFirma> createState() => _ModalFirmaState();
}

class _ModalFirmaState extends State<_ModalFirma> {
  late final SignatureController _controller;
  bool _firmado = false;

  @override
  void initState() {
    super.initState();
    // Inicializa el controlador de firma con trazo negro de 2px.
    _controller = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    // Escucha cambios en el controlador para saber si hay trazo.
    _controller.addListener(() {
      if (_controller.isNotEmpty && !_firmado) {
        setState(() => _firmado = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Convierte la firma a PNG base64 y la devuelve como resultado del modal.
  Future<void> _confirmar() async {
    final bytes = await _controller.toPngBytes();
    if (bytes == null) return;
    final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
    if (mounted) Navigator.of(context).pop(base64Str);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── HANDLE (barra de arrastre) ────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── TITULO ────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Firma del cliente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // Boton X para cerrar sin firmar.
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Firma dentro del recuadro',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),

          // ── CANVAS DE FIRMA ───────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Signature(
                controller: _controller,
                height: 220,
                backgroundColor: Colors.grey.shade50,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── BOTONES ───────────────────────────────────────
          Row(
            children: [
              // Boton Limpiar: borra el trazo.
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Limpiar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _firmado = false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Boton Confirmar: solo activo si hay trazo.
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Confirmar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _firmado ? _confirmar : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

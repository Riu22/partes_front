import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SeccionFirma extends StatefulWidget {
  final void Function(String? base64, String? nombreFirma) onFirmaChanged;

  const SeccionFirma({super.key, required this.onFirmaChanged});

  @override
  State<SeccionFirma> createState() => _SeccionFirmaState();
}

class _SeccionFirmaState extends State<SeccionFirma> {
  late final SignatureController _controller;
  final _nombreCtrl = TextEditingController();
  bool _firmado = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _controller.addListener(() {
      if (_controller.isNotEmpty && !_firmado) {
        setState(() => _firmado = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmarFirma() async {
    final bytes = await _controller.toPngBytes();
    if (bytes == null) return;
    final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
    final nombre = _nombreCtrl.text.trim().isEmpty
        ? null
        : _nombreCtrl.text.trim();
    widget.onFirmaChanged(base64Str, nombre);
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

  void _limpiarFirma() {
    _controller.clear();
    setState(() => _firmado = false);
    widget.onFirmaChanged(null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Firma del cliente(OPCIONAL)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
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
          'El cliente puede firmar aquí para confirmar la realización del trabajo',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // ── Nombre del firmante ──────────────────────────────
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

        // ── Pad de firma ─────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Signature(
              controller: _controller,
              height: 160,
              backgroundColor: Colors.grey.shade50,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Firmar con el dedo en el recuadro',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Limpiar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
                onPressed: _limpiarFirma,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirmar firma'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: _firmado ? _confirmarFirma : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

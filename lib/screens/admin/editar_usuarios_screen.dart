import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class EditarUsuarioScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> usuario;
  const EditarUsuarioScreen({super.key, required this.usuario});

  @override
  ConsumerState<EditarUsuarioScreen> createState() =>
      _EditarUsuarioScreenState();
}

class _EditarUsuarioScreenState extends ConsumerState<EditarUsuarioScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _codigoCtrl;
  late String _rol;
  late bool _activo;
  late bool _postventa;
  bool _enviando = false;

  bool get _puedeSerPostventa => _rol == 'OPERARIO' || _rol == 'ENCARGADO';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.usuario['name'] ?? '');
    _lastNameCtrl = TextEditingController(
      text: widget.usuario['apellidos'] ?? '',
    );
    _codigoCtrl = TextEditingController(text: widget.usuario['codigo'] ?? '');
    _rol = widget.usuario['rol'] ?? 'OPERARIO';
    _activo = widget.usuario['activo'] ?? true;
    _postventa = widget.usuario['postventa'] ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar — ${_nameCtrl.text}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Apellidos',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(
                labelText: 'Código',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _rol,
              decoration: const InputDecoration(
                labelText: 'Rol',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'OPERARIO', child: Text('Operario')),
                DropdownMenuItem(value: 'ENCARGADO', child: Text('Encargado')),
                DropdownMenuItem(
                  value: 'JEFE_DE_OBRA',
                  child: Text('Jefe de obra'),
                ),
                DropdownMenuItem(value: 'GESTION', child: Text('Gestión')),
                DropdownMenuItem(
                  value: 'ADMINISTRACION',
                  child: Text('Administración'),
                ),
              ],
              onChanged: (v) => setState(() {
                _rol = v!;
                if (!_puedeSerPostventa) _postventa = false;
              }),
            ),
            SwitchListTile(
              title: const Text('Usuario activo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
            if (_puedeSerPostventa)
              SwitchListTile(
                title: const Text('Operario de postventa'),
                value: _postventa,
                onChanged: (v) => setState(() => _postventa = v),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: _enviando ? null : _guardar,
                child: _enviando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('GUARDAR CAMBIOS'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    setState(() => _enviando = true);
    try {
      await ref.read(apiServiceProvider).editarUsuario(widget.usuario['id'], {
        'name': _nameCtrl.text.trim(),
        'apellidos': _lastNameCtrl.text.trim(),
        'codigo': _codigoCtrl.text.trim(),
        'rol': _rol,
        'activo': _activo,
        'postventa': _postventa,
      });
      ref.invalidate(usuariosProvider);
      if (mounted) {
        context.go('/usuarios');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

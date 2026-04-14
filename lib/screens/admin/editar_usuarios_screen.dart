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
    _codigoCtrl = TextEditingController(text: widget.usuario['codigo'] ?? '');
    _rol = widget.usuario['rol'] ?? 'OPERARIO';
    _activo = widget.usuario['activo'] ?? true;
    _postventa = widget.usuario['postventa'] ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar — ${widget.usuario['name'] ?? ''}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
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
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Usuario activo'),
              subtitle: Text(_activo ? 'Activo' : 'Inactivo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
            // Solo mostrar si el rol puede ser postventa
            if (_puedeSerPostventa)
              SwitchListTile(
                title: const Text('Operario de postventa'),
                subtitle: Text(
                  _postventa
                      ? 'Verá el formulario de especialidad'
                      : 'Formulario estándar',
                ),
                value: _postventa,
                onChanged: (v) => setState(() => _postventa = v),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _enviando ? null : _guardar,
                child: _enviando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'GUARDAR CAMBIOS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
        'codigo': _codigoCtrl.text.trim(),
        'rol': _rol,
        'activo': _activo,
        'postventa': _postventa,
      });
      ref.invalidate(usuariosProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Usuario actualizado')));
        context.go('/usuarios');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

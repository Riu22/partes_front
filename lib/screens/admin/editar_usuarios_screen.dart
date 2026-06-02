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
  late final TextEditingController _grupoProfesionalCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;

  late String _rol;
  late String _especialidad;
  late bool _activo;
  late bool _postventa;
  String? _grupoProfesionalSeleccionado;
  bool _grupoPersonalizado = false;
  bool _enviando = false;
  bool _mostrarPassword = false;

  static const List<String> _gruposOpciones = [
    'OF 1ª - Electricidad',
    'OF 2ª - Electricidad',
    'OF 3ª - Electricidad',
    'Peón - Electricidad',
    'OF 1ª - Fontanería',
    'OF 2ª - Fontanería',
    'OF 3ª - Fontanería',
    'Peón - Fontanería',
    'OF 1ª - Climatización',
    'OF 2ª - Climatización',
    'OF 3ª - Climatización',
    'Peón - Climatización',
    'Peón - Almacén',
    'Jefe de Obra',
    'Encargado',
    'Otro (escribir a mano)',
  ];

  bool get _puedeSerPostventa => _rol == 'OPERARIO' || _rol == 'ENCARGADO';

  String get _grupoFinal {
    if (_grupoPersonalizado) return _grupoProfesionalCtrl.text.trim();
    return _grupoProfesionalSeleccionado ?? '';
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.usuario['name'] ?? '');
    _lastNameCtrl = TextEditingController(
      text: widget.usuario['apellidos'] ?? '',
    );
    _codigoCtrl = TextEditingController(text: widget.usuario['codigo'] ?? '');
    _emailCtrl = TextEditingController(text: widget.usuario['email'] ?? '');
    _passwordCtrl = TextEditingController(); // siempre vacío por seguridad

    _rol = widget.usuario['rol'] ?? 'OPERARIO';
    _activo = widget.usuario['activo'] ?? true;
    _postventa = widget.usuario['postventa'] ?? false;
    _especialidad = widget.usuario['especialidad'] ?? 'ELECTRICIDAD';

    final grupoActual = widget.usuario['grupo_profesional']?.toString() ?? '';
    if (grupoActual.isEmpty) {
      _grupoProfesionalSeleccionado = null;
      _grupoPersonalizado = false;
    } else if (_gruposOpciones.contains(grupoActual)) {
      _grupoProfesionalSeleccionado = grupoActual;
      _grupoPersonalizado = false;
    } else {
      _grupoProfesionalSeleccionado = 'Otro (escribir a mano)';
      _grupoPersonalizado = true;
    }
    _grupoProfesionalCtrl = TextEditingController(
      text: _grupoPersonalizado ? grupoActual : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _codigoCtrl.dispose();
    _grupoProfesionalCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar — ${_nameCtrl.text}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECCIÓN: Datos personales ──────────────────────────────
            _seccionTitulo('Datos personales'),
            const SizedBox(height: 12),

            // Nombre y apellidos
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

            // Código
            TextFormField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(
                labelText: 'Código',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 24),

            // ── SECCIÓN: Acceso ────────────────────────────────────────
            _seccionTitulo('Acceso'),
            const SizedBox(height: 12),

            // Email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Contraseña
            TextFormField(
              controller: _passwordCtrl,
              obscureText: !_mostrarPassword,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                hintText: 'Dejar vacío para no cambiarla',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _mostrarPassword = !_mostrarPassword),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── SECCIÓN: Rol y permisos ────────────────────────────────
            _seccionTitulo('Rol y permisos'),
            const SizedBox(height: 12),

            // Rol
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
            const SizedBox(height: 8),

            // Activo
            SwitchListTile(
              title: const Text('Usuario activo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),

            // Postventa
            if (_puedeSerPostventa)
              SwitchListTile(
                title: const Text('Operario de postventa'),
                value: _postventa,
                onChanged: (v) => setState(() => _postventa = v),
              ),

            const SizedBox(height: 24),

            // ── SECCIÓN: Especialidad y categoría ─────────────────────
            _seccionTitulo('Especialidad y categoría'),
            const SizedBox(height: 12),

            // Especialidad
            DropdownButtonFormField<String>(
              value: _especialidad,
              decoration: const InputDecoration(
                labelText: 'Especialidad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.build),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'ELECTRICIDAD',
                  child: Text('Electricidad'),
                ),
                DropdownMenuItem(
                  value: 'FONTANERIA',
                  child: Text('Fontanería'),
                ),
              ],
              onChanged: (v) => setState(() => _especialidad = v!),
            ),
            const SizedBox(height: 16),

            // Grupo profesional
            DropdownButtonFormField<String>(
              value: _grupoProfesionalSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Categoría profesional',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              hint: const Text('Seleccionar categoría'),
              items: _gruposOpciones.map((grupo) {
                final esOtro = grupo == 'Otro (escribir a mano)';
                return DropdownMenuItem(
                  value: grupo,
                  child: Text(
                    grupo,
                    style: TextStyle(
                      color: esOtro ? Colors.blueAccent : null,
                      fontStyle: esOtro ? FontStyle.italic : null,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (v) {
                setState(() {
                  _grupoProfesionalSeleccionado = v;
                  _grupoPersonalizado = v == 'Otro (escribir a mano)';
                  if (!_grupoPersonalizado) _grupoProfesionalCtrl.clear();
                });
              },
            ),

            // Campo libre si elige "Otro"
            if (_grupoPersonalizado) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _grupoProfesionalCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Escribe la categoría profesional',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                  hintText: 'Ej: OF 4ª - Climatización',
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Botón guardar
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

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Cabecera de sección con línea divisoria
  Widget _seccionTitulo(String titulo) {
    return Row(
      children: [
        Text(
          titulo.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }

  Future<void> _guardar() async {
    // Validación mínima de contraseña
    if (_passwordCtrl.text.isNotEmpty && _passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      await ref.read(apiServiceProvider).editarUsuario(widget.usuario['id'], {
        'name': _nameCtrl.text.trim(),
        'apellidos': _lastNameCtrl.text.trim(),
        'codigo': _codigoCtrl.text.trim(),
        'rol': _rol,
        'activo': _activo,
        'postventa': _postventa,
        'especialidad': _especialidad,
        'grupo_profesional': _grupoFinal,
        'email': _emailCtrl.text.trim(),
        if (_passwordCtrl.text.isNotEmpty) 'password': _passwordCtrl.text,
      });
      ref.invalidate(usuariosProvider);
      if (mounted) context.go('/usuarios');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}
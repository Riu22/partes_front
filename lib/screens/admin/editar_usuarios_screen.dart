// =============================================================================
// editar_usuarios_screen.dart
// =============================================================================
// QUE ES:       Pantalla para editar un usuario existente.
// PARA QUE:     Modificar datos personales, email, contrasena (opcional),
//               rol, estado activo, postventa, especialidad y categoria.
// QUIEN LO USA: Administradores.
// COMO SE LLEGA: Desde usuarios_screen.dart al pulsar "Editar" en un usuario.
// A DONDE VA:   PUT /api/usuarios/{id} (servidor).
// QUE DATOS USA: admin_provider, auth_provider.
// OFFLINE:      No aplica.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

/// Formulario para editar un usuario existente. Permite cambiar todos
/// los campos incluyendo contrasena (opcional), rol, especialidad y
/// categoria profesional.
class EditarUsuarioScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> usuario;
  const EditarUsuarioScreen({super.key, required this.usuario});

  @override
  ConsumerState<EditarUsuarioScreen> createState() =>
      _EditarUsuarioScreenState();
}

/// Estado del formulario de edicion: inicializa controladores con datos
/// existentes, gestiona cambios y envio.
class _EditarUsuarioScreenState extends ConsumerState<EditarUsuarioScreen> {
  // -- Controladores --
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _grupoProfesionalCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;

  // -- Estado --
  late String _rol;
  late String _especialidad;
  late bool _activo;
  late bool _postventa;
  String? _grupoProfesionalSeleccionado;
  bool _grupoPersonalizado = false;
  bool _enviando = false;
  bool _mostrarPassword = false;

  // Opciones de grupo profesional
  static const List<String> _gruposOpciones = [
    'OF 1a - Electricidad',
    'OF 2a - Electricidad',
    'OF 3a - Electricidad',
    'Peon - Electricidad',
    'OF 1a - Fontaneria',
    'OF 2a - Fontaneria',
    'OF 3a - Fontaneria',
    'Peon - Fontaneria',
    'OF 1a - Climatizacion',
    'OF 2a - Climatizacion',
    'OF 3a - Climatizacion',
    'Peon - Climatizacion',
    'Peon - Almacen',
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
    // Inicializa controladores con datos existentes
    _nameCtrl = TextEditingController(text: widget.usuario['name'] ?? '');
    _lastNameCtrl = TextEditingController(
      text: widget.usuario['apellidos'] ?? '',
    );
    _codigoCtrl = TextEditingController(text: widget.usuario['codigo'] ?? '');
    _emailCtrl = TextEditingController(text: widget.usuario['email'] ?? '');
    _passwordCtrl = TextEditingController(); // Siempre vacio por seguridad

    _rol = widget.usuario['rol'] ?? 'OPERARIO';
    _activo = widget.usuario['activo'] ?? true;
    _postventa = widget.usuario['postventa'] ?? false;
    _especialidad = widget.usuario['especialidad'] ?? 'ELECTRICIDAD';

    // Determina si el grupo profesional es uno predefinido o personalizado
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
      appBar: AppBar(title: Text('Editar - ${_nameCtrl.text}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- SECCION: Datos personales ----
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

            // Codigo
            TextFormField(
              controller: _codigoCtrl,
              decoration: const InputDecoration(
                labelText: 'Codigo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 24),

            // ---- SECCION: Acceso ----
            _seccionTitulo('Acceso'),
            const SizedBox(height: 12),

            // Email
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electronico',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Contrasena (opcional)
            TextFormField(
              controller: _passwordCtrl,
              obscureText: !_mostrarPassword,
              decoration: InputDecoration(
                labelText: 'Nueva contrasena',
                hintText: 'Dejar vacio para no cambiarla',
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

            // ---- SECCION: Rol y permisos ----
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
                DropdownMenuItem(value: 'GESTION', child: Text('Gestion')),
                DropdownMenuItem(
                  value: 'ADMINISTRACION',
                  child: Text('Administracion'),
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

            // ---- SECCION: Especialidad y categoria ----
            _seccionTitulo('Especialidad y categoria'),
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
                  child: Text('Fontaneria'),
                ),
              ],
              onChanged: (v) => setState(() => _especialidad = v!),
            ),
            const SizedBox(height: 16),

            // Grupo profesional
            DropdownButtonFormField<String>(
              value: _grupoProfesionalSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Categoria profesional',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              hint: const Text('Seleccionar categoria'),
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
                  labelText: 'Escribe la categoria profesional',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                  hintText: 'Ej: OF 4a - Climatizacion',
                ),
              ),
            ],

            const SizedBox(height: 32),

            // ---- Boton guardar ----
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

  /// Cabecera de seccion con linea divisoria.
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

  /// Guarda los cambios del usuario en el servidor.
  Future<void> _guardar() async {
    // Validacion minima de contrasena
    if (_passwordCtrl.text.isNotEmpty && _passwordCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contrasena debe tener al menos 6 caracteres'),
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

// =============================================================================
// crear_usuarios_screen.dart
// =============================================================================
// QUE ES:       Pantalla para crear un nuevo usuario en el sistema.
// PARA QUE:     Registrar un usuario con nombre, apellidos, codigo, email,
//               contrasena, rol, especialidad y categoria profesional.
// QUIEN LO USA: Administradores.
// COMO SE LLEGA: Desde usuarios_screen.dart al pulsar FAB.
// A DONDE VA:   POST /api/usuarios (servidor).
// QUE DATOS USA: admin_provider, auth_provider.
// OFFLINE:      No aplica.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

/// Formulario completo para crear un nuevo usuario con todos sus datos:
/// personales, acceso, rol, especialidad y categoria profesional.
class CrearUsuarioScreen extends ConsumerStatefulWidget {
  const CrearUsuarioScreen({super.key});

  @override
  ConsumerState<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

/// Estado del formulario de creacion: gestiona controladores,
/// validacion, seleccion de rol/especialidad/grupo y envio.
class _CrearUsuarioScreenState extends ConsumerState<CrearUsuarioScreen> {
  // -- Claves y controladores --
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _grupoProfesionalCtrl = TextEditingController();

  // -- Estado del formulario --
  String _rol = 'OPERARIO';
  bool _postventa = false;
  bool _enviando = false;
  String _especialidad = 'ELECTRICIDAD';
  String? _grupoProfesionalSeleccionado;
  bool _grupoPersonalizado = false;

  // Opciones de grupo profesional predefinidas
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

  bool get _puedeSerPostventa => _rol == 'OPERARIO' || _rol == 'JEFE_DE_OBRA';

  // Devuelve el grupo profesional final (seleccionado o escrito a mano)
  String get _grupoFinal {
    if (_grupoPersonalizado) return _grupoProfesionalCtrl.text.trim();
    return _grupoProfesionalSeleccionado ?? '';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _codigoCtrl.dispose();
    _grupoProfesionalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/usuarios');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nuevo usuario'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/usuarios'),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- Nombre y apellidos ----
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
                        validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Apellidos',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ---- Codigo ----
                TextFormField(
                  controller: _codigoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Codigo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Email ----
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (v) =>
                      v!.isEmpty ? 'El email es obligatorio' : null,
                ),
                const SizedBox(height: 16),

                // ---- Contrasena ----
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contrasena',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (v) =>
                      v!.length < 6 ? 'Minimo 6 caracteres' : null,
                ),
                const SizedBox(height: 16),

                // ---- Rol ----
                DropdownButtonFormField<String>(
                  value: _rol,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'OPERARIO',
                      child: Text('Operario'),
                    ),
                    DropdownMenuItem(
                      value: 'ENCARGADO',
                      child: Text('Encargado'),
                    ),
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

                // ---- Postventa (solo si aplica) ----
                if (_puedeSerPostventa) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Operario de postventa'),
                    subtitle: Text(
                      _postventa
                          ? 'Vera el formulario de especialidad'
                          : 'Formulario estandar',
                    ),
                    value: _postventa,
                    onChanged: (v) => setState(() => _postventa = v),
                  ),
                ],

                const SizedBox(height: 16),

                // ---- Especialidad ----
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
                      child: Text('ELECTRICIDAD'),
                    ),
                    DropdownMenuItem(
                      value: 'FONTANERIA',
                      child: Text('FONTANERIA'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _especialidad = v!),
                  validator: (v) =>
                      v == null ? 'Selecciona una especialidad' : null,
                ),
                const SizedBox(height: 16),

                // ---- Grupo profesional (dropdown) ----
                DropdownButtonFormField<String>(
                  value: _grupoProfesionalSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Categoria Profesional',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
                  hint: const Text('Seleccionar categoria profesional'),
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

                // ---- Campo libre para grupo personalizado ----
                if (_grupoPersonalizado) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _grupoProfesionalCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Escribe el grupo profesional',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit),
                      hintText: 'Ej: OF 4a - Climatizacion',
                    ),
                    validator: (v) {
                      if (_grupoPersonalizado &&
                          (v == null || v.trim().isEmpty)) {
                        return 'Escribe el grupo profesional';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // ---- Boton crear ----
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _enviando ? null : _crear,
                    child: _enviando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'CREAR USUARIO',
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
        ),
      ),
    );
  }

  /// Envia los datos de creacion al servidor.
  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      await ref.read(apiServiceProvider).crearUsuario({
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'apellidos': _lastNameCtrl.text.trim(),
        'codigo': _codigoCtrl.text.trim(),
        'rol': _rol,
        'postventa': _postventa,
        'especialidad': _especialidad,
        'grupo_profesional': _grupoFinal,
      });
      ref.invalidate(usuariosProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado correctamente')),
        );
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

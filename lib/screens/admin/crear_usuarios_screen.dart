import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class CrearUsuarioScreen extends ConsumerStatefulWidget {
  const CrearUsuarioScreen({super.key});

  @override
  ConsumerState<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends ConsumerState<CrearUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _grupoProfesionalCtrl = TextEditingController();

  String _rol = 'OPERARIO';
  bool _postventa = false;
  bool _enviando = false;
  String _especialidad = 'ELECTRICIDAD';
  String? _grupoProfesionalSeleccionado;
  bool _grupoPersonalizado = false;

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

  bool get _puedeSerPostventa => _rol == 'OPERARIO' || _rol == 'JEFE_DE_OBRA';

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

                // Código
                TextFormField(
                  controller: _codigoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),

                // Email
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

                // Contraseña
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (v) =>
                      v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 16),

                // Rol
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

                // Postventa
                if (_puedeSerPostventa) ...[
                  const SizedBox(height: 8),
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
                ],

                const SizedBox(height: 16),

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

                // Grupo profesional — desplegable
                DropdownButtonFormField<String>(
                  value: _grupoProfesionalSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Categoría Profesional',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
                  hint: const Text('Seleccionar categoría profesional'),
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
                      labelText: 'Escribe el grupo profesional',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit),
                      hintText: 'Ej: OF 4ª - Climatización',
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

                // Botón crear
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

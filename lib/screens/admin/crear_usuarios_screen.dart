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
  String _rol = 'OPERARIO';
  bool _postventa = false;
  bool _enviando = false;
  String _especialidad = 'ELECTRICIDAD';
  final _grupoProfesionalCtrl = TextEditingController();

  bool get _puedeSerPostventa => _rol == 'OPERARIO' || _rol == 'JEFE_DE_OBRA';

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
                TextFormField(
                  controller: _codigoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),
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
                    // Si cambia a un rol que no puede ser postventa, resetear
                    if (!_puedeSerPostventa) _postventa = false;
                  }),
                ),
                // Solo mostrar si el rol puede ser postventa
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
                  onChanged: (String? newValue) {
                    setState(() {
                      _especialidad = newValue!;
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Selecciona una especialidad' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _grupoProfesionalCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Grupo Profesional',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
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
        'grupo_profesional': _grupoProfesionalCtrl.text.trim(),
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

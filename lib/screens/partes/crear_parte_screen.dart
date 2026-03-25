import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';

class CrearParteScreen extends ConsumerStatefulWidget {
  const CrearParteScreen({super.key});

  @override
  ConsumerState<CrearParteScreen> createState() => _CrearParteScreenState();
}

class _CrearParteScreenState extends ConsumerState<CrearParteScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _fecha = DateTime.now();
  double _horasNormales = 8.0;
  final double _horasExtra = 0.0;
  String _descripcion = '';
  int? _idObraSeleccionada;
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Parte Diario'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Información de Obra",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              obrasAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error cargando obras: $e'),
                data: (obras) => DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Obra asignada',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.foundation),
                  ),
                  items: obras
                      .map(
                        (o) => DropdownMenuItem<int>(
                          value: o.id,
                          child: Text(o.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _idObraSeleccionada = val),
                  validator: (val) => val == null ? 'Selecciona la obra' : null,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  "Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}",
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 25),
              const Text(
                "Registro de Horas",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Horas',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          _horasNormales = double.tryParse(v) ?? 8.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                "Tareas Realizadas",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              TextFormField(
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe brevemente qué has hecho hoy...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val!.isEmpty ? 'Debes detallar las tareas' : null,
                onChanged: (v) => _descripcion = v,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _enviando ? null : _enviarParte,
                  child: _enviando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ENVIAR PARTE',
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
    );
  }

  void _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;

    final perfil = ref.read(authProvider).valueOrNull;
    if (perfil == null) return;

    setState(() => _enviando = true);
    try {
      await ref.read(apiServiceProvider).crearParte({
        'id_obra': _idObraSeleccionada,
        'id_perfil': perfil.id,
        'fecha': DateFormat('yyyy-MM-dd').format(_fecha),
        'horas_normales': _horasNormales,
        'descripcion': _descripcion,
      });
      ref.invalidate(partesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        context.go('/partes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

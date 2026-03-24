import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear fechas

class CrearParteScreen extends StatefulWidget {
  const CrearParteScreen({super.key});

  @override
  State<CrearParteScreen> createState() => _CrearParteScreenState();
}

class _CrearParteScreenState extends State<CrearParteScreen> {
  final _formKey = GlobalKey<FormState>();

  // Datos del parte
  DateTime _fecha = DateTime.now();
  double _horasNormales = 8.0;
  String _descripcion = "";
  int? _idObraSeleccionada;

  // Lista de obras (Esto vendrá de tu API obra_repo.findAll())
  final List<Map<String, dynamic>> _obras = [
    {'id': 1, 'nombre': 'Residencial Palma'},
    {'id': 2, 'nombre': 'Reforma Hotel Sol'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Parte Diario'),
        backgroundColor: Colors.orange[800], // Color construcción
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

              // Selector de Obra
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Obra asignada',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.foundation),
                ),
                items: _obras
                    .map(
                      (o) => DropdownMenuItem<int>(
                        value: o['id'],
                        child: Text(o['nombre']),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _idObraSeleccionada = val),
                validator: (val) => val == null ? 'Selecciona la obra' : null,
              ),
              const SizedBox(height: 20),

              // Selector de Fecha
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
                      initialValue: "8",
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Horas Normales',
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

              // Botón de Envío
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _enviarAlEncargado,
                  child: const Text(
                    'ENVIAR AL ENCARGADO',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  void _enviarAlEncargado() {
    if (_formKey.currentState!.validate()) {
      // Aquí llamarías a tu servicio de API
      print("Obra ID: $_idObraSeleccionada");
      print("Tareas: $_descripcion");
      // Al guardar, el backend pondrá 'firmado = false'
      // para que el Encargado lo vea en su lista.

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parte enviado correctamente')),
      );
      Navigator.pop(context);
    }
  }
}

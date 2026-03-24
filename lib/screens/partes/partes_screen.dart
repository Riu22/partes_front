import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PartesScreen extends StatefulWidget {
  const PartesScreen({super.key});

  @override
  State<PartesScreen> createState() => _PartesScreenState();
}

class _PartesScreenState extends State<PartesScreen> {
  // Simulación de datos que vendrían de tu API: get_partes_jerarquico(uuid)
  final List<Map<String, dynamic>> _partes = [
    {
      'id': 101,
      'obra': 'Castanyete 3',
      'operario': 'Juan Pérez',
      'fecha': DateTime.now(),
      'horas': 8.5,
      'firmado': true,
      'descripcion': 'Colocación de ferralla en cimentación.',
    },
    {
      'id': 102,
      'obra': 'Castanyete 3',
      'operario': 'Pedro Luis',
      'fecha': DateTime.now(),
      'horas': 8.0,
      'firmado': false,
      'descripcion': 'Limpieza de zona y acopio de materiales.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Partes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        itemCount: _partes.length,
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemBuilder: (context, index) {
          final parte = _partes[index];
          final bool estaFirmado = parte['firmado'];

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              leading: Icon(
                estaFirmado ? Icons.verified : Icons.pending_actions,
                color: estaFirmado ? Colors.green : Colors.orange,
                size: 30,
              ),
              title: Text(
                parte['obra'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "${parte['operario']} • ${DateFormat('dd/MM/yyyy').format(parte['fecha'])}",
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${parte['horas']}h",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    estaFirmado ? "FIRMADO" : "PENDIENTE",
                    style: TextStyle(
                      fontSize: 10,
                      color: estaFirmado ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Descripción del trabajo:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(parte['descripcion']),
                      const SizedBox(height: 15),

                      // BOTÓN DE ACCIÓN: Solo si NO está firmado y el usuario es ENCARGADO
                      if (!estaFirmado)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _validarParte(parte['id']),
                            icon: const Icon(Icons.edit_note),
                            label: const Text("FIRMAR PARTE (ENCARGADO)"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _validarParte(int id) {
    // Aquí llamarías a tu partes_service.validar_parte(id, mi_uuid)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Validar parte?"),
        content: const Text(
          "Al firmar confirmas que las horas y tareas son correctas.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () {
              // Lógica para actualizar en el backend
              Navigator.pop(context);
            },
            child: const Text("CONFIRMAR FIRMA"),
          ),
        ],
      ),
    );
  }
}

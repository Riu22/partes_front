// =============================================================================
// PANTALLA: FormularioParteJefe
// -----------------------------------------------------------------------------
// QUE ES: Formulario para crear un parte de jefe de obra.
// PARA QUE SIRVE: Registrar rango de fechas, obras con horas electricas/mecanicas.
// QUIEN LA VE (rol): Jefes de obra.
// COMO SE LLEGA: Desde crear_parte_screen (role-based routing).
// A DONDE VA DESPUES: Vuelve a '/partes' al enviar o cancelar.
// QUE DATOS NECESITA: Lista de obras, fechas de inicio y fin.
// OFFLINE: Si, guarda en cola offline si no hay conexion.
// =============================================================================

/// Formulario para crear un parte de jefe de obra.
/// Permite seleccionar un rango de fechas (inicio y fin), anadir una o
/// varias obras con horas electricas y mecanicas desglosadas, y escribir
/// una descripcion general. Si no hay conexion, se guarda en la cola offline.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/obras_provider.dart';
import '../../providers/partes_provider.dart';
import '../../widgets/buscador_obras_modal.dart';

/// Formulario para que el jefe de obra cree un parte con rango de fechas,
/// multiples obras y horas desglosadas en electricas y mecanicas.
/// Soporta guardado offline cuando no hay conexion.
class FormularioParteJefe extends ConsumerStatefulWidget {
  const FormularioParteJefe({super.key});

  @override
  ConsumerState<FormularioParteJefe> createState() =>
      _FormularioParteJefeState();
}

/// Estado del formulario de parte de jefe.
///
/// Lifecycle:
/// 1. initState: no requiere inicializacion especial.
/// 2. build: renderiza el formulario con selector de fechas y obras.
/// 3. dispose: no requiere limpieza especial.
class _FormularioParteJefeState extends ConsumerState<FormularioParteJefe> {
  final _formKey = GlobalKey<FormState>();
  String _descripcion = '';
  bool _enviando = false;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

    // Cada linea representa una obra con sus horas desglosadas en electricas y mecanicas
    // { obra_id, obra_nombre, horas_electricas, horas_mecanicas }
  final List<Map<String, dynamic>> _lineas = [];

  // Suma todas las horas electricas y mecanicas de todas las lineas de obra
  double get _totalHorasIntroducidas => _lineas.fold(
    0.0,
    (sum, l) =>
        sum +
        ((l['horas_electricas'] as double?) ?? 0.0) +
        ((l['horas_mecanicas'] as double?) ?? 0.0),
  );

  // Valida que el rango de fechas sea correcto
  bool get _fechasValidas =>
      _fechaInicio != null &&
      _fechaFin != null &&
      !_fechaFin!.isBefore(_fechaInicio!);

  // El formulario esta listo cuando hay fechas validas y al menos una obra
  bool get _formularioListo =>
      _fechasValidas && _lineas.isNotEmpty && !_enviando;

  // -- Selector de fecha ------------------------------------------------------
  /// Abre el DatePicker para seleccionar fecha de inicio o fin.
  /// Si se cambia la fecha de inicio y la fecha fin queda anterior,
  /// se resetea la fecha fin.
  Future<void> _seleccionarFecha({required bool esInicio}) async {
    final ahora = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: esInicio ? (_fechaInicio ?? ahora) : (_fechaFin ?? ahora),
      firstDate: DateTime(ahora.year - 1),
      lastDate: DateTime(ahora.year + 1),
      locale: const Locale('es'),
    );
    if (picked == null) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = picked;
        // Si la fecha fin es anterior a la nueva fecha de inicio, la reseteamos
        if (_fechaFin != null && _fechaFin!.isBefore(picked)) {
          _fechaFin = null;
        }
      } else {
        _fechaFin = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parte Jefe de Obra'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/partes'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -- Rango de fechas ------------------------------------------
              const Text(
                'Periodo del parte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSelectorFecha(
                      label: 'Fecha inicio',
                      valor: _fechaInicio != null
                          ? fmt.format(_fechaInicio!)
                          : 'Seleccionar',
                      onTap: () => _seleccionarFecha(esInicio: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSelectorFecha(
                      label: 'Fecha fin',
                      valor: _fechaFin != null
                          ? fmt.format(_fechaFin!)
                          : 'Seleccionar',
                      onTap: () => _seleccionarFecha(esInicio: false),
                    ),
                  ),
                ],
              ),
              // Mensaje de advertencia si las fechas no son validas
              if (!_fechasValidas &&
                  (_fechaInicio != null || _fechaFin != null))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'La fecha fin debe ser igual o posterior a la fecha inicio',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 25),

              // -- Obras ----------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Obras',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_lineas.isNotEmpty)
                    Text(
                      'Total: ${_totalHorasIntroducidas.toStringAsFixed(1)} h',
                      style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Renderiza las lineas de obra existentes
              ..._lineas.asMap().entries.map(
                (e) => _buildCardLinea(e.key, e.value),
              ),

              // Boton para anadir obras disponibles
              obrasAsync.when(
                loading: () => const SizedBox(),
                error: (e, _) => const SizedBox(),
                data: (obras) {
                  // Filtra obras que aun no estan en la lista
                  final obraIds = _lineas.map((l) => l['obra_id']).toSet();
                  final disponibles = obras
                      .where((o) => !obraIds.contains(o.id))
                      .toList();
                  if (disponibles.isEmpty) return const SizedBox();
                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal,
                    ),
                    onPressed: () =>
                        abrirBuscadorObras(context, disponibles, (o) {
                          setState(
                            () => _lineas.add({
                              'obra_id': o.id,
                              'obra_nombre': o.nombre,
                              'horas_electricas': 0.0,
                              'horas_mecanicas': 0.0,
                            }),
                          );
                        }),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar y anadir obra'),
                  );
                },
              ),

              const SizedBox(height: 25),

              // -- Descripcion ----------------------------------------------
              const Text(
                'Descripcion general',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                maxLines: 4,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                onChanged: (v) => _descripcion = v,
              ),

              const SizedBox(height: 30),

              // -- Boton enviar ---------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  // Boton habilitado solo cuando el formulario esta completo
                  onPressed: _formularioListo ? _enviarParte : null,
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

  // -- Widgets auxiliares -----------------------------------------------------

  /// Selector visual de fecha con formato.
  Widget _buildSelectorFecha({
    required String label,
    required String valor,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.teal.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
        color: Colors.teal.withOpacity(0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.teal),
              const SizedBox(width: 6),
              Text(
                valor,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  /// Tarjeta para una linea de obra con inputs de horas electricas y mecanicas.
  Widget _buildCardLinea(int i, Map<String, dynamic> linea) {
    final electricas = (linea['horas_electricas'] as double?) ?? 0.0;
    final mecanicas = (linea['horas_mecanicas'] as double?) ?? 0.0;
    final totalLinea = electricas + mecanicas;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera obra + eliminar
            Row(
              children: [
                Expanded(
                  child: Text(
                    linea['obra_nombre'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _lineas.removeAt(i)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Inputs horas
            Row(
              children: [
                Expanded(
                  child: _buildInputHoras(
                    label: 'Electricas (h)',
                    valor: electricas,
                    onChanged: (v) =>
                        setState(() => _lineas[i]['horas_electricas'] = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputHoras(
                    label: 'Mecanicas (h)',
                    valor: mecanicas,
                    onChanged: (v) =>
                        setState(() => _lineas[i]['horas_mecanicas'] = v),
                  ),
                ),
              ],
            ),
            if (totalLinea > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Subtotal: ${totalLinea.toStringAsFixed(1)} h',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Input numerico para un campo de horas.
  Widget _buildInputHoras({
    required String label,
    required double valor,
    required ValueChanged<double> onChanged,
  }) => TextFormField(
    initialValue: valor == 0 ? '' : valor.toStringAsFixed(1),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    onChanged: (v) => onChanged(double.tryParse(v) ?? 0.0),
  );

  // -- Envio ------------------------------------------------------------------

  /// Envia el parte de jefe al servidor con rango de fechas y obras.
  /// Si no hay red o hay error de conexion, guarda en cola offline.
  ///
  /// Estrategia offline:
  /// 1. Verifica conectividad con Connectivity().checkConnectivity()
  /// 2. Si no hay red, guarda en offlineQueueProvider
  /// 3. Si hay error de red (DioException), tambien guarda en offline
  /// 4. Invalida los providers para actualizar la UI
  Future<void> _enviarParte() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_fechasValidas) return;
    setState(() => _enviando = true);

    final fmt = DateFormat('yyyy-MM-dd');
    // Construye el payload con rango de fechas + lista de obras con horas desglosadas
    final data = <String, dynamic>{
      'descripcion': _descripcion,
      'fecha_inicio': fmt.format(_fechaInicio!),
      'fecha_fin': fmt.format(_fechaFin!),
      'obras': _lineas
          .map(
            (l) => {
              'id_obra': l['obra_id'],
              'horas_electricas': l['horas_electricas'] ?? 0.0,
              'horas_mecanicas': l['horas_mecanicas'] ?? 0.0,
            },
          )
          .toList(),
    };

    try {
      // Verifica conectividad usando connectivity_plus
      final resultado = await Connectivity().checkConnectivity();
      final hayRed = resultado.any((r) => r != ConnectivityResult.none);

      if (!hayRed) {
        // Guarda offline y sale
        await ref.read(offlineQueueProvider).guardarParteJefeOffline(data);
        ref.invalidate(pendientesOfflineProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sin conexion - parte guardado, se enviara automaticamente',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          context.go('/partes');
        }
        return;
      }

      // Envia al servidor
      await ref.read(apiServiceProvider).crearParteJefe(data);
      ref.invalidate(partesJefeProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte enviado correctamente')),
        );
        context.go('/partes');
      }
    } on DioException catch (_) {
      // Error de conexion: guarda en cola offline
      await ref.read(offlineQueueProvider).guardarParteJefeOffline(data);
      ref.invalidate(pendientesOfflineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexion - parte guardado localmente'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/partes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

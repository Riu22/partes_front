import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/parte_trabajo.dart';
import '../../providers/sync_provider.dart';
import '../../providers/obras_provider.dart';
import '../../services/update_service.dart';

// ─── Helpers de fecha (sin intl para evitar LocaleDataException) ──────────────
String _fmtDMY(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtYMD(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmtDayHeader(DateTime d) {
  const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final hoy = DateTime.now();
  final esHoy = d.year == hoy.year && d.month == hoy.month && d.day == hoy.day;
  final sufijo = '${d.day} ${meses[d.month - 1]}';
  return esHoy ? 'Hoy $sufijo' : '${dias[d.weekday - 1]} $sufijo';
}

// ─── Colores de la app ────────────────────────────────────────────────────────
const _bgPage = Color(0xFFE8EAF0);
const _bgCard = Colors.white;
const _blue = Color(0xFF1565C0);
const _bluePill = Color(0xFFE3EDFF);
const _orange = Color(0xFFF57C00);
const _orangePill = Color(0xFFFFF3E0);
const _chipElec = Color(0xFFF57C00);
const _chipFont = Color(0xFF1565C0);
const _textPrimary = Color(0xFF1A1A2E);
const _textSecondary = Color(0xFF888888);
const _cardBorder = Color(0xFFE0E3EA);
const _bgStat = Color(0xFFF1F3F8);

class PartesScreen extends ConsumerStatefulWidget {
  const PartesScreen({super.key});

  @override
  ConsumerState<PartesScreen> createState() => _PartesScreenState();
}

class _PartesScreenState extends ConsumerState<PartesScreen> {
  final _obraCtrl = TextEditingController();
  final _operarioCtrl = TextEditingController();
  String? _especialidadFiltro;
  bool _buscando = false;
  List<dynamic>? _resultadosBusqueda;
  final _updateService = UpdateService();

  bool get _hayFiltros =>
      _obraCtrl.text.isNotEmpty ||
      _operarioCtrl.text.isNotEmpty ||
      _especialidadFiltro != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final conectado = ref.read(conectividadProvider).valueOrNull ?? false;
      if (conectado) {
        ref.invalidate(obrasActivasProvider);
        ref.invalidate(obrasProvider);
      }
      if (!kIsWeb) _checkUpdate();
    });
  }

  Future<void> _checkUpdate() async {
    final update = await _updateService.hayActualizacion();
    if (update != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Nueva versión disponible'),
          content: Text(
            'Hay una actualización a la versión ${update['version']}.\n\n'
            'Descárgala para tener las últimas mejoras.\n\n'
            'Una vez descargado dale a abrir y selecciona actualizar.\n\n'
            'En caso de que de un error desinstale la aplicacion y vuelva a instalarla con el instalador que acaba de descargar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _updateService.abrirDescarga(update['url']!);
              },
              child: const Text('Descargar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _buscar() async {
    if (!_hayFiltros) {
      setState(() => _resultadosBusqueda = null);
      return;
    }
    setState(() => _buscando = true);
    try {
      final r = await ref
          .read(apiServiceProvider)
          .buscarPartes(
            obra: _obraCtrl.text,
            operario: _operarioCtrl.text,
            especialidad: _especialidadFiltro,
          );
      setState(() => _resultadosBusqueda = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _refrescar() async {
    ref.invalidate(partesProvider);
    ref.invalidate(partesJefeProvider);
    ref.invalidate(pendientesOfflineProvider);
  }

  void _limpiarBusqueda() {
    _obraCtrl.clear();
    _operarioCtrl.clear();
    setState(() {
      _especialidadFiltro = null;
      _resultadosBusqueda = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncProvider);
    final pendientesAsync = ref.watch(pendientesOfflineProvider);
    final totalPendientes = pendientesAsync.valueOrNull ?? 0;
    final conexionAsync = ref.watch(conectividadProvider);
    final perfil = ref.watch(authProvider).valueOrNull;

    if (perfil == null) {
      return const Scaffold(
        backgroundColor: _bgPage,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _bgPage,
        elevation: 0,
        title: const Text(
          'Mis partes',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
        ),
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          if (totalPendientes > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Sincronizar partes pendientes',
                onPressed: () {
                  ref.invalidate(syncProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Intentando enviar $totalPendientes parte(s)...',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: Badge(
                  label: Text('$totalPendientes'),
                  backgroundColor: _orange,
                  child: const Icon(Icons.cloud_off, color: _orange, size: 26),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _textPrimary),
            onPressed: _refrescar,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título sección
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Partes de Trabajo',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
          ),

          // Buscador (roles con permiso)
          if (!perfil.esOperario) _buildBuscador(),

          // Banner sin conexión
          conexionAsync.when(
            data: (online) => online
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: Colors.red.shade100,
                    padding: const EdgeInsets.all(6),
                    child: const Text(
                      'Sin conexión — los partes se guardarán en el móvil',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            error: (_, __) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),

          // Lista
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refrescar,
              child: _resultadosBusqueda != null
                  ? _ListaPartes(
                      partes: _resultadosBusqueda!
                          .map((p) => ParteTrabajo.fromJson(p))
                          .toList(),
                    )
                  : perfil.esJefeObra
                  ? const _PartesJefeView()
                  : const _PartesNormalesView(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_partes_unique',
        backgroundColor: _bgCard,
        foregroundColor: _blue,
        elevation: 2,
        onPressed: () => context.go('/partes/nuevo'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  controller: _obraCtrl,
                  hint: 'Obra',
                  icon: Icons.business_outlined,
                  onSubmit: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SearchField(
                  controller: _operarioCtrl,
                  hint: 'Operario',
                  icon: Icons.person_outline,
                  onSubmit: (_) => _buscar(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _cardBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _especialidadFiltro,
                      isDense: true,
                      hint: const Text(
                        'Especialidad',
                        style: TextStyle(fontSize: 14, color: _textSecondary),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Todas')),
                        DropdownMenuItem(
                          value: 'ELECTRICIDAD',
                          child: Text('Electricidad'),
                        ),
                        DropdownMenuItem(
                          value: 'FONTANERIA',
                          child: Text('Fontanería'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _especialidadFiltro = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _buscando ? null : _buscar,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _cardBorder),
                  ),
                  child: _buscando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _blue,
                          ),
                        )
                      : const Row(
                          children: [
                            Icon(Icons.search, size: 16, color: _textPrimary),
                            SizedBox(width: 6),
                            Text(
                              'Buscar',
                              style: TextStyle(
                                fontSize: 14,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (_hayFiltros)
                IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 18,
                    color: _textSecondary,
                  ),
                  onPressed: _limpiarBusqueda,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Campo de búsqueda con estilo de la app ───────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onSubmit;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: _textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, size: 18, color: _textSecondary),
        filled: true,
        fillColor: _bgCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue),
        ),
        isDense: true,
      ),
      onSubmitted: onSubmit,
    );
  }
}

// ─── Banner resumen semanal ───────────────────────────────────────────────────
class _ResumenSemanal extends StatelessWidget {
  final List<ParteTrabajo> partes;

  const _ResumenSemanal({required this.partes});

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
    final finSemana = inicioSemana.add(const Duration(days: 6));

    final partesSemana = partes.where((p) {
      return !p.fecha.isBefore(
            DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day),
          ) &&
          !p.fecha.isAfter(
            DateTime(finSemana.year, finSemana.month, finSemana.day, 23, 59),
          );
    }).toList();

    final totalSemana = partesSemana.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );

    final partesHoy = partes.where(
      (p) =>
          p.fecha.year == ahora.year &&
          p.fecha.month == ahora.month &&
          p.fecha.day == ahora.day,
    );
    final horasHoy = partesHoy.fold<double>(0, (s, p) => s + p.horasNormales);

    final progreso = (totalSemana / 40).clamp(0.0, 1.0);
    final hayExtra = horasHoy > 8;

    String _fmt(double h) =>
        h == h.truncateToDouble() ? '${h.toInt()}' : h.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTA SEMANA',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.5,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Total',
                  value: '${_fmt(totalSemana)}h',
                  valueColor: _blue,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatBox(
                  label: 'Partes',
                  value: '${partesSemana.length}',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatBox(
                  label: 'Hoy',
                  value: '${_fmt(horasHoy)}h',
                  valueColor: hayExtra ? _orange : _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 3,
              backgroundColor: _bgStat,
              valueColor: AlwaysStoppedAnimation(
                totalSemana > 40 ? _orange : _blue,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '0h',
                style: TextStyle(fontSize: 10, color: _textSecondary),
              ),
              if (hayExtra)
                Text(
                  'Hoy: ${_fmt(horasHoy)}h · jornada 8h',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const Text(
                '40h',
                style: TextStyle(fontSize: 10, color: _textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatBox({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bgStat,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: _textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: valueColor ?? _textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lista con agrupación por día ─────────────────────────────────────────────
class _ListaPartes extends StatelessWidget {
  final List<ParteTrabajo> partes;
  final bool mostrarResumen;

  const _ListaPartes({required this.partes, this.mostrarResumen = false});

  @override
  Widget build(BuildContext context) {
    if (partes.isEmpty) {
      return const Center(
        child: Text(
          'No hay partes registrados',
          style: TextStyle(color: _textSecondary),
        ),
      );
    }

    // Agrupar por fecha (solo año/mes/día)
    final Map<String, List<ParteTrabajo>> grupos = {};
    for (final p in partes) {
      final key = _fmtYMD(p.fecha);
      grupos.putIfAbsent(key, () => []).add(p);
    }
    // Ordenar fechas descendente
    final fechasOrdenadas = grupos.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (mostrarResumen) _ResumenSemanal(partes: partes),
        for (final fecha in fechasOrdenadas) ...[
          _DayHeader(fecha: DateTime.parse(fecha), partes: grupos[fecha]!),
          for (final p in grupos[fecha]!)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _CardParte(parte: p),
            ),
        ],
      ],
    );
  }
}

// ─── Cabecera de día con total de horas ───────────────────────────────────────
class _DayHeader extends StatelessWidget {
  final DateTime fecha;
  final List<ParteTrabajo> partes;

  const _DayHeader({required this.fecha, required this.partes});

  @override
  Widget build(BuildContext context) {
    final totalHoras = partes.fold<double>(0, (s, p) => s + p.horasNormales);
    final hoy = DateTime.now();
    final esHoy =
        fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
    final hayExtra = esHoy && totalHoras > 8;

    String horasLabel;
    if (totalHoras == totalHoras.truncateToDouble()) {
      horasLabel = '${totalHoras.toInt()}h';
    } else {
      horasLabel = '${totalHoras.toStringAsFixed(1)}h';
    }
    if (hayExtra) {
      final extra = totalHoras - 8;
      final extraStr = extra == extra.truncateToDouble()
          ? '${extra.toInt()}'
          : extra.toStringAsFixed(1);
      horasLabel += ' · +${extraStr} extra';
    }

    final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final diaStr =
        '${dias[fecha.weekday - 1]} ${fecha.day} ${meses[fecha.month - 1]}';
    final fechaStr = esHoy
        ? 'Hoy ${fecha.day} ${meses[fecha.month - 1]}'
        : diaStr;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            fechaStr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: hayExtra ? _orangePill : _bluePill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              horasLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: hayExtra ? _orange : _blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de parte (operario / encargado / administración) ────────────────────
class _CardParte extends ConsumerWidget {
  final ParteTrabajo parte;

  const _CardParte({required this.parte});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;
    final esGestor = perfil?.esAdmin == true || perfil?.esGestion == true;
    // Gestores pueden editar cualquier parte; el resto solo los de hoy
    final puedeEditar = esGestor || parte.puedeEditarse;
    final String? esp = parte.especialidad;
    final bool esElec = esp == 'ELECTRICIDAD';

    return Card(
      color: _bgCard,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _cardBorder),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: puedeEditar ? _orangePill : _bgStat,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.assignment_outlined,
            size: 18,
            color: puedeEditar ? _orange : _textSecondary,
          ),
        ),
        title: Text(
          parte.obraNombre,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textPrimary,
          ),
        ),
        subtitle: Text(
          '${parte.operarioNombre} · ${_fmtDMY(parte.fecha)}',
          style: const TextStyle(fontSize: 12, color: _textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${parte.horasNormales % 1 == 0 ? parte.horasNormales.toInt() : parte.horasNormales}h',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
                height: 1,
              ),
            ),
            if (esp != null) ...[
              const SizedBox(height: 4),
              _ChipEspecialidad(especialidad: esp, esElec: esElec),
            ],
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _cardBorder)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Descripción',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  parte.descripcion.isNotEmpty
                      ? parte.descripcion
                      : 'Sin descripción',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textPrimary,
                    height: 1.5,
                  ),
                ),
                if (puedeEditar) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textPrimary,
                        side: const BorderSide(color: _cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () =>
                          context.go('/partes/editar', extra: parte),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text(
                        'Editar parte',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip de especialidad ─────────────────────────────────────────────────────
class _ChipEspecialidad extends StatelessWidget {
  final String especialidad;
  final bool esElec;

  const _ChipEspecialidad({required this.especialidad, required this.esElec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: esElec ? _chipElec : _chipFont,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        esElec ? 'ELECT.' : 'FONT.',
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Vista partes normales ────────────────────────────────────────────────────
class _PartesNormalesView extends ConsumerWidget {
  const _PartesNormalesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;

    // Resumen semanal solo para operario y encargado
    final mostrarResumen =
        perfil?.esOperario == true || perfil?.esEncargado == true;

    return partesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _blue)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: _textSecondary)),
      ),
      data: (partes) =>
          _ListaPartes(partes: partes, mostrarResumen: mostrarResumen),
    );
  }
}

// ─── Vista partes jefe de obra ────────────────────────────────────────────────
class _PartesJefeView extends ConsumerWidget {
  const _PartesJefeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesJefeProvider);
    return partesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: _blue)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: _textSecondary)),
      ),
      data: (partes) {
        if (partes.isEmpty) {
          return const Center(
            child: Text(
              'No hay partes registrados',
              style: TextStyle(color: _textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
          itemCount: partes.length,
          itemBuilder: (context, index) => _CardParteJefe(parte: partes[index]),
        );
      },
    );
  }
}

// ─── Card jefe de obra ────────────────────────────────────────────────────────
class _CardParteJefe extends StatelessWidget {
  final dynamic parte;

  const _CardParteJefe({required this.parte});

  @override
  Widget build(BuildContext context) {
    final fechaStr = parte['fecha'] ?? '';
    final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();
    final obras = (parte['obras'] as List?) ?? [];
    final hoy = DateTime.now();
    final puedeEditar =
        fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
    final descripcion =
        (parte['descripcion'] != null &&
            parte['descripcion'].toString().isNotEmpty)
        ? parte['descripcion']
        : 'Sin descripción';

    return Card(
      color: _bgCard,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _cardBorder),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: puedeEditar ? _orangePill : _bgStat,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.assignment_outlined,
            size: 18,
            color: puedeEditar ? _orange : _textSecondary,
          ),
        ),
        title: Text(
          _fmtDMY(fecha),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textPrimary,
          ),
        ),
        subtitle: Text(
          '${obras.length} obra(s)',
          style: const TextStyle(fontSize: 12, color: _textSecondary),
        ),
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _cardBorder)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribución',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...obras.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.business_outlined,
                          size: 14,
                          color: _blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            o['obra']?['nombre'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: _textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${o['porcentaje']}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: _cardBorder),
                const Text(
                  'Descripción',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

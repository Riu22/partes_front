// =============================================================================
// resumen_mensual_jefe_screen.dart
// =============================================================================
// QUE ES:       Pantalla de resumen mensual de dedicacion del jefe de obra.
// PARA QUE:     Mostrar horas totales por operario y obra con porcentajes
//               electricos y mecanicos para un mes seleccionable.
// QUIEN LO USA: Jefes de obra (ven su equipo) y administradores (ven todos).
// COMO SE LLEGA: Desde el AppDrawer o menu de navegacion.
// A DONDE VA:   GET /api/resumen-mensual (servidor).
// QUE DATOS USA: auth_provider, partes_provider, tema_constants, app_drawer.
// OFFLINE:      No aplica.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../helpers/tema_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/partes_provider.dart';
import '../../widgets/app_drawer.dart';

/// Resumen mensual de dedicacion: para cada operario muestra las horas
/// por obra con porcentajes de especialidad (electrico/mecanico).
/// Los administradores ven todos los usuarios; los jefes solo los suyos.
class ResumenMensualJefeScreen extends ConsumerStatefulWidget {
  const ResumenMensualJefeScreen({super.key});

  @override
  ConsumerState<ResumenMensualJefeScreen> createState() =>
      _ResumenMensualJefeScreenState();
}

/// Estado del resumen mensual: gestiona mes/anio seleccionados,
/// carga de datos y construccion de la UI.
class _ResumenMensualJefeScreenState
    extends ConsumerState<ResumenMensualJefeScreen> {
  late int _anio; // Anio seleccionado
  late int _mes; // Mes seleccionado (1-12)

  // Nombres de meses en espanol
  static const _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _anio = ahora.year;
    _mes = ahora.month;
  }

  /// Navega al mes anterior.
  void _anteriorMes() => setState(() {
    if (_mes == 1) {
      _mes = 12;
      _anio--;
    } else {
      _mes--;
    }
  });

  /// Navega al mes siguiente.
  void _siguienteMes() => setState(() {
    if (_mes == 12) {
      _mes = 1;
      _anio++;
    } else {
      _mes++;
    }
  });

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(authProvider).valueOrNull;
    // Determina si es admin/gestion (ve todos) o jefe (ve solo su equipo)
    final esAdmin = perfil?.esAdmin == true || perfil?.esGestion == true;
    final params = (anio: _anio, mes: _mes);

    // Provider segun el rol
    final asyncData = esAdmin
        ? ref.watch(resumenMensualPorUsuarioProvider(params))
        : ref.watch(resumenMensualJefeProvider(params)).whenData((r) => [r]);

    return Scaffold(
      drawer: const AppDrawer(),

      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: bgCard,
        elevation: 0,
        title: const Text(
          'Dedicacion mensual',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      body: Column(
        children: [
          // ---- Selector de mes ----
          Container(
            color: bgCard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _anteriorMes,
                  icon: const Icon(Icons.chevron_left, color: textPrimary),
                ),
                Text(
                  '${_meses[_mes - 1]} $_anio',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: _siguienteMes,
                  icon: const Icon(Icons.chevron_right, color: textPrimary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: cardBorder),

          // ---- Lista de usuarios con su dedicacion ----
          Expanded(
            child: asyncData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (usuarios) {
                if (usuarios.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sin dedicacion este mes',
                      style: TextStyle(color: textSecondary),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: usuarios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, i) {
                    final u = usuarios[i] as Map<String, dynamic>;
                    final nombre = u['nombre'] as String? ?? '--';
                    final totalHoras = u['total_horas_laborables'] as num?;
                    final obras = (u['obras'] as List?) ?? [];

                    return Container(
                      decoration: BoxDecoration(
                        color: bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ---- Cabecera del usuario ----
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: cardBorder),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: bluePill,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline,
                                    color: blue,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                // Badge con total de horas
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bluePill,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${totalHoras?.toStringAsFixed(2) ?? '--'} h',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ---- Obras del usuario ----
                          if (obras.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'Sin obras',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else ...[
                            ...obras.asMap().entries.map((e) {
                              final o = e.value as Map<String, dynamic>;
                              final esUltimo = e.key == obras.length - 1;
                              final hE =
                                  (o['horas_electricas'] as num?)
                                      ?.toStringAsFixed(2) ??
                                  '0.00';
                              final hM =
                                  (o['horas_mecanicas'] as num?)
                                      ?.toStringAsFixed(2) ??
                                  '0.00';
                              final pctE =
                                  (o['porcentaje_electrico'] as num?)
                                      ?.toStringAsFixed(2) ??
                                  '0.00';
                              final pctM =
                                  (o['porcentaje_mecanico'] as num?)
                                      ?.toStringAsFixed(2) ??
                                  '0.00';

                              return Container(
                                decoration: BoxDecoration(
                                  border: esUltimo
                                      ? null
                                      : const Border(
                                          bottom: BorderSide(color: cardBorder),
                                        ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Nombre de la obra
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.business_outlined,
                                          size: 13,
                                          color: blue,
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            o['nombre_obra'] ?? '--',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Chips de electrico y mecanico
                                    Row(
                                      children: [
                                        _chip(
                                          'E',
                                          '$pctE%',
                                          '$hE h',
                                          orangePill,
                                          orange,
                                        ),
                                        const SizedBox(width: 8),
                                        _chip(
                                          'M',
                                          '$pctM%',
                                          '$hM h',
                                          bluePill,
                                          blue,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),

                            // ---- Totales del usuario ----
                            Builder(
                              builder: (_) {
                                // Calcula totales electricos y mecanicos
                                double totalE = obras.fold(
                                  0.0,
                                  (s, o) =>
                                      s +
                                      ((o
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >)['horas_electricas']
                                                  as num? ??
                                              0)
                                          .toDouble(),
                                );
                                double totalM = obras.fold(
                                  0.0,
                                  (s, o) =>
                                      s +
                                      ((o
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >)['horas_mecanicas']
                                                  as num? ??
                                              0)
                                          .toDouble(),
                                );
                                final base = (totalHoras ?? 0).toDouble();
                                final pctE = base > 0
                                    ? (totalE / base) * 100
                                    : 0.0;
                                final pctM = base > 0
                                    ? (totalM / base) * 100
                                    : 0.0;
                                final pctTotal = pctE + pctM;
                                // Verifica si suma 100% (con tolerancia)
                                final esCien = (pctTotal - 100.0).abs() < 0.01;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: cardBorder),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Fila de totales
                                      Row(
                                        children: [
                                          const Text(
                                            'Total',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _chip(
                                            'E',
                                            '${pctE.toStringAsFixed(2)}%',
                                            '${totalE.toStringAsFixed(2)} h',
                                            orangePill,
                                            orange,
                                          ),
                                          const SizedBox(width: 8),
                                          _chip(
                                            'M',
                                            '${pctM.toStringAsFixed(2)}%',
                                            '${totalM.toStringAsFixed(2)} h',
                                            bluePill,
                                            blue,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Indicador de total combinado
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: esCien
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: esCien
                                                ? const Color(0xFF81C784)
                                                : const Color(0xFFFFB74D),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              esCien
                                                  ? Icons.check_circle_outline
                                                  : Icons.warning_amber_rounded,
                                              size: 16,
                                              color: esCien
                                                  ? const Color(0xFF388E3C)
                                                  : const Color(0xFFE65100),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Total dedicacion: ${pctTotal.toStringAsFixed(2)}%',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: esCien
                                                    ? const Color(0xFF388E3C)
                                                    : const Color(0xFFE65100),
                                              ),
                                            ),
                                            if (!esCien) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '(faltan ${(100.0 - pctTotal).toStringAsFixed(2)}%)',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFFE65100),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Chip visual con emoji/letra, porcentaje y horas.
  /// pct es el valor grande (principal), horas es el pequeno (secundario).
  Widget _chip(
    String emoji,
    String pct,
    String horas,
    Color bgColor,
    Color textColor,
  ) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pct,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                horas,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

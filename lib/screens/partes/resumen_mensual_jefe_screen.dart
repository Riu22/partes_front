import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../helpers/tema_constants.dart';
import '../../providers/partes_provider.dart';

class ResumenMensualJefeScreen extends ConsumerStatefulWidget {
  const ResumenMensualJefeScreen({super.key});

  @override
  ConsumerState<ResumenMensualJefeScreen> createState() =>
      _ResumenMensualJefeScreenState();
}

class _ResumenMensualJefeScreenState
    extends ConsumerState<ResumenMensualJefeScreen> {
  late int _anio;
  late int _mes;

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

  void _anteriorMes() => setState(() {
    if (_mes == 1) {
      _mes = 12;
      _anio--;
    } else {
      _mes--;
    }
  });

  void _siguienteMes() => setState(() {
    if (_mes == 12) {
      _mes = 1;
      _anio++;
    } else {
      _mes++;
    }
  });

  String _fmtFecha(String? fecha) {
    if (fecha == null) return '—';
    final d = DateTime.tryParse(fecha);
    if (d == null) return fecha;
    return DateFormat('dd/MM/yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final params = (anio: _anio, mes: _mes);
    final resumenAsync = ref.watch(resumenMensualJefeProvider(params));

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: bgCard,
        elevation: 0,
        title: const Text(
          'Dedicación mensual',
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
          // ── Selector mes ────────────────────────────────────
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

          // ── Contenido ───────────────────────────────────────
          Expanded(
            child: resumenAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (resumen) {
                final obras = (resumen['obras'] as List?) ?? [];
                final partes = (resumen['partes'] as List?) ?? [];
                final totalHoras = resumen['total_horas_laborables'] as num?;

                if (partes.isEmpty) {
                  return const Center(
                    child: Text(
                      'Sin partes este mes',
                      style: TextStyle(color: textSecondary),
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Total horas ──────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: bluePill,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.schedule_outlined,
                                color: blue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total horas laborables',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                                Text(
                                  '${totalHoras?.toStringAsFixed(1) ?? '—'} h',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Dedicación por obra ──────────────
                      const Text(
                        'DEDICACIÓN POR OBRA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (obras.isEmpty)
                        const Text(
                          'Sin obras este mes',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            children: obras.asMap().entries.map((e) {
                              final i = e.key;
                              final o = e.value as Map<String, dynamic>;
                              final esUltimo = i == obras.length - 1;
                              final pctE =
                                  (o['porcentaje_electrico'] as num?)
                                      ?.toStringAsFixed(1) ??
                                  '0';
                              final pctM =
                                  (o['porcentaje_mecanico'] as num?)
                                      ?.toStringAsFixed(1) ??
                                  '0';
                              final hE = o['horas_electricas'] ?? 0;
                              final hM = o['horas_mecanicas'] ?? 0;

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
                                  vertical: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.business_outlined,
                                          size: 14,
                                          color: blue,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            o['nombre_obra'] ?? '—',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _dedicacionChip(
                                          '⚡',
                                          '$hE h',
                                          '$pctE%',
                                          orangePill,
                                          orange,
                                        ),
                                        const SizedBox(width: 8),
                                        _dedicacionChip(
                                          '🔧',
                                          '$hM h',
                                          '$pctM%',
                                          bluePill,
                                          blue,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // ── Partes del mes ───────────────────
                      const Text(
                        'PARTES DEL MES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...partes.map((p) {
                        final parte = p as Map<String, dynamic>;
                        return Card(
                          color: bgCard,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: cardBorder),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: bgStat,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.assignment_outlined,
                                size: 18,
                                color: blue,
                              ),
                            ),
                            title: Text(
                              '${_fmtFecha(parte['fecha_inicio']?.toString())} → ${_fmtFecha(parte['fecha_fin']?.toString())}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${parte['total_horas_laborables'] ?? '—'} h  ·  ${parte['descripcion'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: blue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: () => context.push(
                                '/partes-jefe/informe/${parte['id']}',
                                extra: _fmtFecha(
                                  parte['fecha_inicio']?.toString(),
                                ),
                              ),
                              child: const Text(
                                'Ver',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dedicacionChip(
    String emoji,
    String horas,
    String pct,
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
                horas,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                pct,
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

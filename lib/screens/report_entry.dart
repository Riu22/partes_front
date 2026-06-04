/// Punto de entrada diferido (lazy) para las pantallas de informes.
/// Se usa desde el enrutador para crear las pantallas de:
/// - Informe de partes (PDF/ZIP)
/// - Informe de dedicación del jefe de obra
/// - Resumen mensual del jefe de obra
import 'package:flutter/material.dart';
import 'pdf/pdf_screen.dart';
import 'partes/informe_jefe_screen.dart';
import 'partes/resumen_mensual_jefe_screen.dart';

/// Crea la pantalla de informe de partes (exportación PDF/ZIP).
Widget makeInformePartesScreen() => const InformePartesScreen();

/// Crea la pantalla de informe de dedicación horaria del jefe de obra.
Widget makeInformeJefeScreen() => const InformeJefeScreen();

/// Crea la pantalla de resumen mensual de dedicación del jefe de obra.
Widget makeResumenMensualJefeScreen() => const ResumenMensualJefeScreen();

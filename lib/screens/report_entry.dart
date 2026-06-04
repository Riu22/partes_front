// =============================================================================
// PANTALLA: report_entry.dart
// -----------------------------------------------------------------------------
// QUE ES: Punto de entrada diferido (lazy) para las pantallas de informes.
// PARA QUE SIRVE: Crea las pantallas de informe solo cuando se necesitan.
// QUIEN LA VE (rol): No es una pantalla, es un modulo de fabrica.
// COMO SE LLEGA: Se importa desde el enrutador.
// A DONDE VA DESPUES: Devuelve las pantallas de informe correspondientes.
// QUE DATOS NECESITA: Ninguno, solo funciones fabrica.
// OFFLINE: N/A, es solo codigo de enrutamiento.
// =============================================================================

/// Punto de entrada diferido (lazy) para las pantallas de informes.
/// Se usa desde el enrutador para crear las pantallas de:
/// - Informe de partes (PDF/ZIP)
/// - Informe de dedicacion del jefe de obra
/// - Resumen mensual del jefe de obra
///
/// La carga diferida (lazy loading) mejora el rendimiento inicial
/// al no crear estas pantallas hasta que se navega a ellas.
import 'package:flutter/material.dart';
import 'pdf/pdf_screen.dart';
import 'partes/informe_jefe_screen.dart';
import 'partes/resumen_mensual_jefe_screen.dart';

/// Crea la pantalla de informe de partes (exportacion PDF/ZIP).
Widget makeInformePartesScreen() => const InformePartesScreen();

/// Crea la pantalla de informe de dedicacion horaria del jefe de obra.
Widget makeInformeJefeScreen() => const InformeJefeScreen();

/// Crea la pantalla de resumen mensual de dedicacion del jefe de obra.
Widget makeResumenMensualJefeScreen() => const ResumenMensualJefeScreen();

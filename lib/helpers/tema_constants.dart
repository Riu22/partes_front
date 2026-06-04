// =============================================================================
//  tema_constants.dart  -  CONSTANTES DE COLORES DEL TEMA DE LA APLICACION
// =============================================================================
//  QUE ES UN HELPER?
//  En esta aplicacion, un "helper" es una herramienta o modulo ligero que
//  encapsula una funcionalidad especifica. En este caso, el "helper"
//  es un conjunto de constantes de color que definen la paleta visual
//  de la aplicacion. No es una funcion ni una clase, sino un archivo
//  de constantes que sirve como punto unico de referencia para los
//  colores.
//
//  QUE HACE ESTE ARCHIVO?
//  Define todos los colores fijos que se usan en la aplicacion para
//  mantener un diseno uniforme y consistente. En lugar de escribir
//  valores hexadecimales directamente en los widgets, se usan estas
//  constantes con nombres descriptivos. Esto facilita:
//    1. Mantener la consistencia visual: el mismo color se usa en
//       todas partes.
//    2. Cambiar el tema: si se quiere cambiar un color, solo se
//       modifica aqui y se actualiza en toda la app.
//    3. Leer el codigo: los nombres describen el proposito del color.
//
//  CATEGORIAS DE COLORES:
//    - Fondo de pantalla y tarjetas
//    - Colores principales (azul, naranja)
//    - Colores de estado (verde OK, rojo alerta)
//    - Colores para chips y etiquetas
//    - Colores de texto (primario, secundario)
//    - Colores de bordes
// =============================================================================

import 'package:flutter/material.dart'; // Clase Color de Flutter

// =============================================================================
//  COLORES DE FONDO Y SUPERFICIES
// =============================================================================

/// Color de fondo de las pantallas principales.
/// Gris azulado muy claro para no cansar la vista.
const bgPage = Color(0xFFE8EAF0);

/// Color de fondo de las tarjetas (cards).
/// Blanco puro para contrastar con el fondo gris.
const bgCard = Colors.white;

// =============================================================================
//  COLORES PRINCIPALES (AZUL)
// =============================================================================

/// Azul principal para textos importantes, iconos y elementos
/// interactivos destacados. Es el color corporativo de la app.
const blue = Color(0xFF1565C0);

/// Fondo azul claro para etiquetas o "pildoras" informativas
/// (como badges o chips de categoria).
const bluePill = Color(0xFFE3EDFF);

// =============================================================================
//  COLORES DE ACENTO (NARANJA)
// =============================================================================

/// Naranja principal para elementos de advertencia o para destacar
/// informacion importante (como horas extra, alertas suaves).
const orange = Color(0xFFF57C00);

/// Fondo naranja claro para etiquetas o pildoras de advertencia.
const orangePill = Color(0xFFFFF3E0);

// =============================================================================
//  COLORES DE CHIPS
// =============================================================================

/// Color de fondo para los chips que indican "electricidad" o tipo
/// de obra. Naranja para que destaque.
const chipElec = Color(0xFFF57C00);

/// Color del texto dentro de los chips. Azul corporativo para
/// mantener la coherencia visual.
const chipFont = Color(0xFF1565C0);

// =============================================================================
//  COLORES DE TEXTO
// =============================================================================

/// Color principal del texto en la aplicacion.
/// Casi negro con un tono azulado muy sutil (#1A1A2E).
const textPrimary = Color(0xFF1A1A2E);

/// Color para textos secundarios o menos importantes,
/// como subtitulos, descripciones o metadatos.
const textSecondary = Color(0xFF888888);

// =============================================================================
//  COLORES DE BORDES
// =============================================================================

/// Color de los bordes de las tarjetas (cards).
/// Gris claro para dar un efecto de elevacion sutil.
const cardBorder = Color(0xFFE0E3EA);

// =============================================================================
//  COLORES DE ESTADO
// =============================================================================

/// Fondo de las tarjetas de estadisticas (cards con numeros).
/// Gris muy claro para diferenciarlas de las tarjetas normales.
const bgStat = Color(0xFFF1F3F8);

/// Verde para indicar que todo esta correcto (OK), datos validos
/// o estados positivos.
const greenOk = Color(0xFF2E7D32);

/// Fondo verde claro para etiquetas o pildoras de estado OK.
const greenPill = Color(0xFFE8F5E9);

/// Rojo para alertas, errores o situaciones que requieren atencion.
const redAlert = Color(0xFFC62828);

/// Fondo rojo claro para etiquetas o pildoras de alerta/error.
const redPill = Color(0xFFFFEBEE);

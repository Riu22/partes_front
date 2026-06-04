import 'package:flutter/foundation.dart';

/// ============================================================================
/// ENUM: ModoExport
/// ============================================================================
///
/// QUE REPRESENTA:
///   Enumera los formatos de exportacion disponibles para los partes de
///   trabajo en PDF. El usuario puede elegir como quiere recibir los
///   documentos generados.
///
/// VALORES:
///
///   zip:
///     Genera un archivo ZIP que contiene todos los PDFs individuales
///     de cada parte de trabajo. Es util cuando se quiere enviar por
///     email o descargar muchos partes a la vez sin agruparlos.
///     Ejemplo: "partes_2024_01.zip" con 50 PDFs dentro.
///
///   pdf:
///     Genera un unico archivo PDF que contiene TODOS los partes de
///     trabajo concatenados, uno detras de otro. Es util para imprimir
///     o presentar como un unico documento. Ejemplo: "informe_enero.pdf".
///
///   zipOperario:
///     Similar a [zip], pero los PDFs se organizan en carpetas dentro
///     del ZIP, una carpeta por operario. Es util para repartir los
///     partes a cada trabajador o para archivar por empleado.
///     Ejemplo: "partes_por_operario.zip" con carpetas "Juan/",
///     "Maria/", etc.
///
/// ============================================================================
enum ModoExport { zip, pdf, zipOperario }

/// ============================================================================
/// MODELO: PdfParams
/// ============================================================================
///
/// QUE REPRESENTA:
///   Contiene los parametros de filtrado que el usuario selecciona en la
///   pantalla de exportacion de partes a PDF. Define QUE partes se van
///   a exportar y en QUE formato.
///
/// ANALOGIA DEL MUNDO REAL:
///   Imagina que estas en una fotocopiadora y quieres sacar copias de
///   los partes de trabajo. Antes de darle al boton "imprimir", tienes
///   que configurar:
///
///     1. RANGO DE FECHAS: "Desde el 1 de enero hasta el 15 de enero".
///        (campos [desde] y [hasta]).
///
///     2. OBRAS: "Solo las obras con ID 5, 12 y 23".
///        (campo [obraIds], lista de enteros).
///
///     3. OPERARIOS: "Solo los operarios con IDs 'usr-001' y 'usr-002'".
///        (campo [perfilIds], lista de strings).
///
///     4. FORMATO: "En un solo PDF" o "En un ZIP con varios PDFs".
///        (campo [modo], tipo ModoExport).
///
/// INMUTABILIDAD:
///   La clase esta decorada con @immutable, lo que indica que todas las
///   instancias deben ser inmutables (nunca cambiar sus campos despues
///   de creadas). Esto es importante en Flutter porque los widgets que
///   usan estos parametros necesitan saber si cambiaron para
///   reconstruirse.
///
///   Para garantizar la inmutabilidad, se sobrescriben los metodos
///   operator == y hashCode. Dos instancias de PdfParams son iguales
///   si todos sus campos son iguales. Esto permite que Flutter compare
///   objetos por valor (no por referencia) y detecte cambios.
///
///   La funcion listEquals (importada de 'package:flutter/foundation.dart')
///   compara dos listas elemento por elemento para determinar si son
///   iguales. Dart no puede comparar listas con == directamente porque
///   compara referencias, no contenido.
///
/// ============================================================================
@immutable
class PdfParams {
  // --------------------------------------------------------------------------
  // CAMPOS (PROPIEDADES)
  // --------------------------------------------------------------------------

  /// Fecha de inicio del rango de filtrado (incluida).
  /// Solo se exportaran los partes de trabajo cuya fecha sea igual o
  /// posterior a esta. Es un objeto DateTime con la fecha que el usuario
  /// selecciono en el selector de fechas de la UI.
  final DateTime desde;

  /// Fecha de fin del rango de filtrado (incluida).
  /// Solo se exportaran los partes cuya fecha sea igual o anterior a
  /// esta. Junto con [desde] define la ventana temporal del informe.
  final DateTime hasta;

  /// Lista de IDs de obras a incluir en la exportacion.
  /// Si la lista esta vacia, se exportan TODAS las obras (sin filtro).
  /// Cada ID es un entero que corresponde al campo [id] del modelo Obra.
  /// Se usa para filtrar partes de obras especificas.
  final List<int> obraIds;

  /// Lista de IDs de perfiles (operarios) a incluir en la exportacion.
  /// Si la lista esta vacia, se exportan TODOS los operarios.
  /// Cada ID es un String que corresponde al campo [id] del modelo Perfil.
  /// Se usa para filtrar partes de operarios concretos.
  final List<String> perfilIds;

  /// Modo de exportacion seleccionado.
  /// Determina si el resultado sera un ZIP, un PDF unico, o un ZIP
  /// organizado por operario. Ver [ModoExport] para detalles.
  final ModoExport modo;

  // --------------------------------------------------------------------------
  // CONSTRUCTOR
  // --------------------------------------------------------------------------

  /// Constructor de PdfParams.
  /// Es "const" para permitir instancias constantes en la UI.
  ///
  /// PARAMETROS:
  ///   [desde] - Fecha inicio del filtro (requerido).
  ///   [hasta] - Fecha fin del filtro (requerido).
  ///   [obraIds] - IDs de obras a filtrar (requerido).
  ///   [perfilIds] - IDs de perfiles a filtrar (requerido).
  ///   [modo] - Modo de exportacion (requerido).
  const PdfParams({
    required this.desde,
    required this.hasta,
    required this.obraIds,
    required this.perfilIds,
    required this.modo,
  });

  // --------------------------------------------------------------------------
  // SOBRECARGA DE OPERADORES (para comparacion por valor)
  // --------------------------------------------------------------------------

  /// OPERADOR: == (igualdad)
  ///
  /// QUE HACE:
  ///   Compara dos objetos PdfParams por su valor (no por referencia
  ///   de memoria). Dos PdfParams son iguales si todos sus campos son
  ///   iguales.
  ///
  /// POR QUE ES NECESARIO:
  ///   En Flutter, cuando un widget depende de un objeto, el framework
  ///   necesita saber si el objeto cambio para decidir si debe
  ///   reconstruir el widget. Sin este operador, Flutter compararia
  ///   por referencia (direccion de memoria), y dos objetos con los
  ///   mismos valores pero diferente instancia serian considerados
  ///   diferentes, causando reconstrucciones innecesarias.
  ///
  /// LOGICA INTERNA:
  ///   1. Comprueba que 'other' sea del tipo PdfParams con 'is'.
  ///   2. Compara cada campo uno por uno:
  ///      - [desde] y [hasta]: se comparan directamente con == porque
  ///        DateTime tiene su propio operador de igualdad.
  ///      - [obraIds] y [perfilIds]: se comparan con listEquals porque
  ///        Dart no puede comparar listas con == (eso compararia la
  ///        referencia, no el contenido).
  ///      - [modo]: se compara directamente con == (enum).
  ///   3. Si todos son iguales, devuelve true.
  ///
  /// PARAMETROS:
  ///   [other] - El otro objeto a comparar (dynamic).
  ///
  /// VALOR DE RETORNO:
  ///   true si los dos objetos tienen el mismo contenido.
  @override
  bool operator ==(Object other) =>
      other is PdfParams &&
      desde == other.desde &&           // Compara fecha inicio
      hasta == other.hasta &&           // Compara fecha fin
      listEquals(obraIds, other.obraIds) &&       // Compara IDs de obras
      listEquals(perfilIds, other.perfilIds) &&   // Compara IDs de perfiles
      modo == other.modo;               // Compara modo de exportacion

  /// GETTER: hashCode
  ///
  /// QUE HACE:
  ///   Genera un codigo hash unico para este objeto basado en el valor
  ///   de todos sus campos. El hash se usa en estructuras de datos como
  ///   HashMap, HashSet, y tambien internamente por Flutter para
  ///   optimizar la deteccion de cambios.
  ///
  /// REGLA IMPORTANTE:
  ///   Si dos objetos son iguales segun ==, deben tener el mismo hashCode.
  ///   Por eso este metodo usa Object.hash() con todos los campos que
  ///   se comparan en el operador ==.
  ///
  /// LOGICA INTERNA:
  ///   Object.hash() es un metodo de utilidad de Dart que genera un
  ///   hash combinando todos los argumentos. Para las listas, usa
  ///   Object.hashAll() que itera sobre los elementos y combina sus
  ///   hashes individuales. Esto asegura que dos listas con los mismos
  ///   elementos (en el mismo orden) generen el mismo hash.
  ///
  /// VALOR DE RETORNO:
  ///   int con el codigo hash del objeto.
  @override
  int get hashCode =>
      Object.hash(
        desde,                           // Hash de fecha inicio
        hasta,                           // Hash de fecha fin
        Object.hashAll(obraIds),         // Hash de lista de obras
        Object.hashAll(perfilIds),       // Hash de lista de perfiles
        modo,                            // Hash del enum de exportacion
      );
}

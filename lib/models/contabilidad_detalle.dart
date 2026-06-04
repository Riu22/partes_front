/// ============================================================================
/// MODELO: ContabilidadDetalle
/// ============================================================================
///
/// QUE REPRESENTA:
///   Este modelo representa el detalle de horas trabajadas por un operario
///   en una obra concreta, desglosadas dia por dia. Se usa en el modulo de
///   contabilidad para generar informes de horas, costes y facturacion.
///
/// ANALOGIA DEL MUNDO REAL:
///   Imagina una hoja de calculo de Excel con las siguientes columnas:
///
///     Codigo  |  Operario  |  Grupo Prof.  |  Obra  |  Horas por dia
///     --------+------------+---------------+--------+-----------------
///     EMP-001 | Juan Perez | OFICIAL_1A    | Obra X | {15/01: 8h,
///     EMP-002 | Maria Ruiz | AYUDANTE      | Obra X |  16/01: 6h,
///                                                     17/01: 8h}
///
///   Cada fila es un ContabilidadDetalle: un operario en una obra,
///   con el detalle de cuantas horas trabajo cada dia del periodo.
///
/// PROPOSITO EN LA APP:
///   Este modelo se usa para:
///     1. Calcular costes de mano de obra por obra (sumar horas * tarifa).
///     2. Generar informes de contabilidad para la direccion.
///     3. Exportar datos a sistemas externos de nomina y facturacion.
///     4. Ver la distribucion de horas de cada operario en el tiempo.
///
/// ESTRUCTURA EN DART:
///   El campo clave es [horasPorDia], un `Map<DateTime, double>` que asocia
///   cada fecha con las horas trabajadas ese dia. Esto permite:
///   - Saber cuantas horas trabajo un operario un dia concreto.
///   - Calcular totales por periodo.
///   - Detectar patrones (dias con menos horas, etc.).
///
///   El campo [totalHoras] es la suma de todas las horas del mapa,
///   almacenada por separado para acceso rapido sin tener que sumar
///   cada vez.
///
/// ============================================================================
class ContabilidadDetalle {
  // --------------------------------------------------------------------------
  // CAMPOS (PROPIEDADES)
  // --------------------------------------------------------------------------

  /// Codigo interno de empleado del operario (ej: "EMP-00123").
  /// Es el mismo codigo que aparece en el perfil del operario.
  /// Se usa como identificador en los informes de contabilidad
  /// y para enlazar con el sistema de nominas externo.
  final String codigo;

  /// Nombre completo del operario (ej: "Juan Perez").
  /// Se almacena como texto plano (desnormalizado) para mostrar
  /// directamente en las tablas de contabilidad sin tener que
  /// cargar el perfil desde la base de datos.
  final String operario;

  /// Grupo profesional del operario segun convenio (ej: "OFICIAL_1A").
  /// Determina la tarifa horaria y el coste para la empresa.
  /// Se usa en los calculos de coste de mano de obra.
  final String grupoProfesional;

  /// Nombre de la obra donde se realizaron los trabajos.
  /// Texto plano (desnormalizado) para mostrar en informes sin
  /// necesidad de cargar el objeto Obra completo.
  final String obra;

  /// Mapa que asocia cada fecha (DateTime) con las horas trabajadas
  /// ese dia (double). La clave es la fecha (sin hora, solo ano/mes/dia)
  /// y el valor son las horas trabajadas (ej: 8.0, 4.5, etc.).
  ///
  /// Este mapa es la parte central del modelo porque permite:
  ///   - Iterar sobre los dias trabajados.
  ///   - Sumar horas de un rango de fechas.
  ///   - Generar graficos de horas por dia.
  ///   - Detectar meses con pocas horas.
  ///
  /// El `Map<DateTime, double>` es un tipo generico de Dart: `Map<K, V>`
  /// donde K es el tipo de la clave (DateTime) y V es el tipo del valor
  /// (double). Esto da seguridad de tipos en tiempo de compilacion.
  final Map<DateTime, double> horasPorDia;

  /// Total de horas trabajadas por este operario en esta obra en el
  /// periodo. Es la suma de todos los valores del mapa [horasPorDia].
  /// Se almacena como campo separado para:
  ///   1. Acceso O(1) sin tener que sumar el mapa cada vez.
  ///   2. Poder ordenar/filtrar por total de horas rapidamente.
  ///   3. Mostrar en columnas de total en tablas e informes.
  final double totalHoras;

  // --------------------------------------------------------------------------
  // CONSTRUCTOR
  // --------------------------------------------------------------------------

  /// Constructor de ContabilidadDetalle.
  ///
  /// PARAMETROS:
  ///   [codigo] - Codigo de empleado (requerido).
  ///   [operario] - Nombre del operario (requerido).
  ///   [grupoProfesional] - Grupo profesional (requerido).
  ///   [obra] - Nombre de la obra (requerido).
  ///   [horasPorDia] - Mapa de fechas a horas (requerido).
  ///   [totalHoras] - Suma total de horas (requerido).
  ContabilidadDetalle({
    required this.codigo,
    required this.operario,
    required this.grupoProfesional,
    required this.obra,
    required this.horasPorDia,
    required this.totalHoras,
  });

  // --------------------------------------------------------------------------
  // FACTORY CONSTRUCTOR: fromJson (DESERIALIZACION)
  // --------------------------------------------------------------------------

  /// FACTORY: ContabilidadDetalle.fromJson
  ///
  /// QUE HACE:
  ///   Construye un objeto ContabilidadDetalle a partir del mapa JSON
  ///   devuelto por el servidor de contabilidad.
  ///
  /// PARAMETROS:
  ///   [json] - `Map<String, dynamic>` con los siguientes campos:
  ///     - 'codigo': String con el codigo de empleado.
  ///     - 'operario': String con el nombre del operario.
  ///     - 'grupo_profesional': String con el grupo profesional.
  ///     - 'obra': String con el nombre de la obra.
  ///     - 'horas_por_dia': `Map<String, dynamic>` donde la clave es
  ///       una fecha en formato "YYYY-MM-DD" y el valor son las horas
  ///       (int o double).
  ///     - 'total_horas': Numero con el total de horas.
  ///
  /// LOGICA INTERNA (PASO A PASO):
  ///
  ///   1. Extrae el mapa 'horas_por_dia' del JSON y lo castea a
  ///      `Map<String, dynamic>`. Las claves son strings con formato
  ///      ISO de fecha (ej: "2024-01-15").
  ///
  ///   2. Crea un `Map<DateTime, double>` vacio llamado horasMap.
  ///
  ///   3. Itera sobre cada par clave-valor del mapa original usando
  ///      forEach. Por cada iteracion:
  ///        a. Convierte la clave (String fecha) a DateTime usando
  ///           DateTime.parse(). Esto parsea el formato ISO "2024-01-15"
  ///           a un objeto DateTime.
  ///        b. Convierte el valor (dynamic) a double usando (value as num)
  ///           seguido de .toDouble(). El casteo a 'num' primero permite
  ///           aceptar tanto int como double en el JSON.
  ///        c. Inserta el par (DateTime, double) en horasMap.
  ///
  ///   4. Construye y devuelve el ContabilidadDetalle con los campos
  ///      directos y el mapa convertido.
  ///
  /// NOTA SOBRE LOS CASTS:
  ///   El campo 'total_horas' viene como 'num' en JSON (podria ser int
  ///   o double). Usamos (json['total_horas'] as num).toDouble() para
  ///   convertir a double de forma segura. Si usasemos 'as double'
  ///   directamente y el servidor enviase un entero (ej: 40), lanzaria
  ///   una excepcion porque 40 en JSON es un int, no un double.
  ///
  /// VALOR DE RETORNO:
  ///   Una nueva instancia de ContabilidadDetalle.
  factory ContabilidadDetalle.fromJson(Map<String, dynamic> json) {
    // ----------------------------------------------------------
    // PASO 1: Extraer y convertir el mapa de horas por dia
    // ----------------------------------------------------------
    // El JSON trae las horas como { "2024-01-15": 8.0, "2024-01-16": 7.5 }
    // Necesitamos convertirlo a Map<DateTime, double> para Dart.
    // Primero obtenemos el mapa raw del JSON
    var horasRaw = json['horas_por_dia'] as Map<String, dynamic>;

    // Creamos un mapa vacio donde guardaremos las fechas como DateTime
    Map<DateTime, double> horasMap = {};

    // Recorremos cada entrada del mapa JSON
    horasRaw.forEach((key, value) {
      // key es String ("2024-01-15"), lo convertimos a DateTime
      // value es dynamic (int o double), lo convertimos a double
      // (value as num) acepta int y double; .toDouble() da siempre double
      horasMap[DateTime.parse(key)] = (value as num).toDouble();
    });

    // ----------------------------------------------------------
    // PASO 2: Construir y devolver el objeto
    // ----------------------------------------------------------
    return ContabilidadDetalle(
      // Codigo de empleado, vacio si no viene
      codigo: json['codigo'] ?? '',
      // Nombre del operario, vacio si no viene
      operario: json['operario'] ?? '',
      // Grupo profesional, vacio si no viene
      grupoProfesional: json['grupo_profesional'] ?? '',
      // Nombre de la obra, vacio si no viene
      obra: json['obra'] ?? '',
      // Mapa de horas por dia ya convertido
      horasPorDia: horasMap,
      // Total de horas: 'num' acepta int/double, .toDouble() lo unifica
      totalHoras: (json['total_horas'] as num).toDouble(),
    );
  }
}

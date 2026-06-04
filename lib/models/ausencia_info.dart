/// ============================================================================
/// ENUM: AusenciaTipo
/// ============================================================================
///
/// QUE REPRESENTA:
///   Enumera los tipos de ausencia laboral que puede tener un operario.
///
/// VALORES:
///   BAJA       - Baja laboral por enfermedad o accidente.
///                El operario no puede trabajar por prescripcion medica.
///   VACACIONES - Periodo de vacaciones anuales pagadas.
///                El operario esta disfrutando de sus dias libres.
///   PATERNIDAD - Permiso de paternidad por nacimiento de hijo.
///                El operario esta ejerciendo su derecho legal.
///
/// ============================================================================
enum AusenciaTipo { BAJA, VACACIONES, PATERNIDAD }

/// ============================================================================
/// MODELO: AusenciaLaboral
/// ============================================================================
///
/// QUE REPRESENTA:
///   Un periodo de tiempo en el que un operario NO esta disponible para
///   trabajar por una causa justificada (baja medica, vacaciones, etc.).
///
/// ANALOGIA DEL MUNDO REAL:
///   Es como una nota en el calendario de la oficina que dice:
///   "Juan no va a estar desde el 15 de enero hasta el 20 de enero porque
///   esta de baja". Con fecha de inicio, fecha de fin y opcionalmente
///   una observacion (ej: "gripe", "operacion", "destino: playa").
///
/// PROPOSITO EN LA APP:
///   Las ausencias se usan para:
///     1. No contar los dias de ausencia como "dias sin parte" (evitar
///        falsos positivos en el control de presencia).
///     2. Mostrar en el calendario del gestor quien esta disponible.
///     3. Calcular nomina (los dias de baja no se pagan igual).
///
/// ESTRUCTURA EN DART:
///   Clase simple con 4 campos. El constructor es "const" (se puede crear
///   en tiempo de compilacion si todos los parametros son constantes).
///   Tiene un factory fromJson para deserializar.
///
/// ============================================================================
class AusenciaLaboral {
  // --------------------------------------------------------------------------
  // CAMPOS (PROPIEDADES)
  // --------------------------------------------------------------------------

  /// Identificador unico de la ausencia en la base de datos.
  /// Es un entero opcional porque cuando se crea una nueva ausencia
  /// localmente (antes de enviarla al servidor) aun no tiene ID.
  /// El servidor asigna el ID al guardar.
  final int? id;

  /// Tipo de ausencia: "BAJA", "VACACIONES" o "PATERNIDAD".
  /// Es un String en lugar de usar el enum [AusenciaTipo] directamente
  /// porque viene del JSON como texto y se almacena asi en la BD.
  /// Si se necesita el enum tipado, se puede convertir con
  /// AusenciaTipo.values.firstWhere(...).
  final String tipo;

  /// Fecha de inicio de la ausencia en formato String.
  /// Se almacena como String (ej: "2024-01-15") en lugar de DateTime
  /// porque viene asi del servidor y en muchos casos solo se muestra
  /// sin necesidad de operaciones de fecha. Si se necesitan calculos,
  /// se convierte con DateTime.parse().
  final String fechaInicio;

  /// Fecha de fin de la ausencia en formato String.
  /// Misma consideracion que [fechaInicio]. Si es una baja sin fecha
  /// de fin conocida, puede ser una fecha futura lejana o null
  /// (aunque en este modelo es obligatoria).
  final String fechaFin;

  /// Observaciones o notas adicionales sobre la ausencia (opcional).
  /// Ej: "Baja por fractura de tobillo", "Vacaciones aprobadas por RRHH",
  /// "Ingreso hospitalario". Es texto libre informativo.
  final String? observaciones;

  // --------------------------------------------------------------------------
  // CONSTRUCTOR
  // --------------------------------------------------------------------------

  /// Constructor de AusenciaLaboral.
  /// Marcado como "const" para permitir instancias constantes.
  ///
  /// PARAMETROS:
  ///   [id] - ID de la ausencia (opcional, null si es nueva).
  ///   [tipo] - Tipo de ausencia (requerido).
  ///   [fechaInicio] - Fecha de inicio (requerido, String).
  ///   [fechaFin] - Fecha de fin (requerido, String).
  ///   [observaciones] - Notas (opcional, null por defecto).
  const AusenciaLaboral({
    this.id,
    required this.tipo,
    required this.fechaInicio,
    required this.fechaFin,
    this.observaciones,
  });

  // --------------------------------------------------------------------------
  // FACTORY CONSTRUCTOR: fromJson
  // --------------------------------------------------------------------------

  /// FACTORY: AusenciaLaboral.fromJson
  ///
  /// QUE HACE:
  ///   Construye un objeto AusenciaLaboral desde un mapa JSON.
  ///
  /// PARAMETROS:
  ///   [json] - `Map<String, dynamic>` con los campos de la ausencia.
  ///            Las claves esperadas son: 'id', 'tipo', 'fechaInicio',
  ///            'fechaFin', 'observaciones'.
  ///
  /// LOGICA INTERNA:
  ///   Usa "as" casting para convertir cada campo al tipo esperado.
  ///   id se castea como int? (nullable), tipo y fechas como String
  ///   (obligatorios), observaciones como String? (nullable).
  ///
  /// VALOR DE RETORNO:
  ///   Una nueva instancia de AusenciaLaboral.
  factory AusenciaLaboral.fromJson(Map<String, dynamic> json) {
    return AusenciaLaboral(
      id: json['id'] as int?,          // ID numerico, nullable
      tipo: json['tipo'] as String,    // Tipo de ausencia (obligatorio)
      fechaInicio: json['fechaInicio'] as String, // Fecha inicio (obligatorio)
      fechaFin: json['fechaFin'] as String,       // Fecha fin (obligatorio)
      observaciones: json['observaciones'] as String?, // Notas (opcional)
    );
  }
}

/// ============================================================================
/// MODELO: DiaIncompleto
/// ============================================================================
///
/// QUE REPRESENTA:
///   Un dia concreto en el que un operario trabajo, pero menos horas de las
///   esperadas. Por ejemplo, si la jornada normal es de 8 horas y el operario
///   solo trabajo 4 horas, ese dia se considera "incompleto".
///
/// ANALOGIA DEL MUNDO REAL:
///   Es como cuando miras el registro de fichaje y ves que Juan entro a las
///   9:00 pero salio a las 13:00 (solo 4 horas). Algo paso: tenia cita
///   medica, se fue antes por emergencia, etc. Este modelo registra ese
///   hecho para que el gestor lo revise.
///
/// DIFERENCIA CON AusenciaLaboral:
///   - AusenciaLaboral: el operario NO trabajo en absoluto (0 horas).
///   - DiaIncompleto: el operario SI trabajo, pero menos horas de las
///     esperadas (ej: 4 de 8 horas).
///
/// ============================================================================
class DiaIncompleto {
  // --------------------------------------------------------------------------
  // CAMPOS
  // --------------------------------------------------------------------------

  /// Fecha en la que ocurrio la jornada incompleta (formato String).
  /// Ej: "2024-01-15". Se mantiene como String porque asi viene del
  /// servidor y solo se muestra en pantallas de control.
  final String fecha;

  /// Horas realmente trabajadas ese dia (como String).
  /// Ej: "4.0", "5.5". Se almacena como String en lugar de double porque
  /// puede venir en formatos variados del servidor y se convierte segun
  /// se necesite con double.parse().
  final String horas;

  // --------------------------------------------------------------------------
  // CONSTRUCTOR
  // --------------------------------------------------------------------------

  /// Constructor de DiaIncompleto.
  /// Marcado como "const" para permitir instancias constantes.
  ///
  /// PARAMETROS:
  ///   [fecha] - Fecha del dia incompleto (requerido).
  ///   [horas] - Horas trabajadas (requerido).
  const DiaIncompleto({required this.fecha, required this.horas});

  // --------------------------------------------------------------------------
  // FACTORY CONSTRUCTOR: fromJson
  // --------------------------------------------------------------------------

  /// FACTORY: DiaIncompleto.fromJson
  ///
  /// QUE HACE:
  ///   Construye un DiaIncompleto desde JSON.
  ///
  /// PARAMETROS:
  ///   [json] - Mapa con campos 'fecha' (String) y 'horas' (dynamic).
  ///
  /// LOGICA INTERNA:
  ///   El campo 'horas' puede venir como int, double o String en el JSON.
  ///   Por eso se usa .toString() para convertirlo siempre a String de
  ///   forma segura, independientemente del tipo original.
  ///
  /// VALOR DE RETORNO:
  ///   Nueva instancia de DiaIncompleto.
  factory DiaIncompleto.fromJson(Map<String, dynamic> json) {
    return DiaIncompleto(
      fecha: json['fecha'] as String,       // Fecha como String
      horas: json['horas'].toString(),       // Horas: cualquier tipo a String
    );
  }
}

/// ============================================================================
/// MODELO: AusenciaInfo
/// ============================================================================
///
/// QUE REPRESENTA:
///   Un resumen completo de las incidencias de presencia de un operario.
///   Agrupa toda la informacion relevante para que el gestor pueda ver
///   de un vistazo si un operario esta al dia con sus partes de trabajo.
///
/// ANALOGIA DEL MUNDO REAL:
///   Imagina que eres el jefe de obra y cada manana revisas un tablero
///   con la situacion de cada operario. Este modelo es ese tablero:
///
///     "Juan Perez"
///     - Dias sin parte:   [15 enero, 16 enero]
///       (no ha rellenado parte esos dias)
///     - Dias incompletos: [17 enero: 4h]
///       (trabajo pero solo 4 de 8 horas)
///     - Ausencias activas: [Baja del 10 al 20 enero]
///       (esta de baja, por eso no ha trabajado)
///     - Total laborables: 22 dias este mes
///     - Fechas habilitadas: [18 enero] (el gestor le permitio editar)
///
/// POR QUE ES UTIL:
///   Sin este modelo, el gestor tendria que revisar manualmente el
///   calendario, los partes, y las ausencias para cada operario.
///   AusenciaInfo lo calcula todo y lo presenta de forma estructurada.
///
/// CAMPOS CLAVE:
///   - [diasSin]: Lista de fechas en las que el operario DEBERIA haber
///                trabajado pero NO tiene parte de trabajo.
///   - [diasIncompletos]: Dias con menos horas de las esperadas.
///   - [ausenciasActivas]: Ausencias justificadas en curso.
///   - [totalLaborables]: Total de dias laborables en el periodo.
///   - [fechasHabilitadas]: Fechas que el gestor ha habilitado para
///     editar partes (por ejemplo, para permitir rellenar partes
///     atrasados al cierre de mes).
///
/// ============================================================================
class AusenciaInfo {
  // --------------------------------------------------------------------------
  // CAMPOS
  // --------------------------------------------------------------------------

  /// ID del perfil del operario al que pertenece esta informacion.
  /// Se usa para enlazar con el objeto Perfil completo y mostrar
  /// datos adicionales (email, especialidad, etc.).
  final String perfilId;

  /// Nombre del operario (texto, no objeto Perfil) para mostrar
  /// directamente en las listas de incidencias sin tener que cargar
  /// el perfil completo. Es "desnormalizacion" para eficiencia.
  final String nombre;

  /// Lista de fechas (como String) en las que el operario no tiene
  /// parte de trabajo registrado pero deberia tenerlo.
  /// Ej: ["2024-01-15", "2024-01-16"].
  /// Cada String es una fecha en formato ISO (YYYY-MM-DD).
  /// Se usa para que el gestor sepa que dias debe reclamar el parte.
  final List<String> diasSin;

  /// Lista de objetos [DiaIncompleto] con los dias en que el operario
  /// trabajo menos horas de las esperadas.
  /// Cada elemento contiene la fecha y las horas realmente trabajadas.
  final List<DiaIncompleto> diasIncompletos;

  /// Lista de objetos [AusenciaLaboral] con las ausencias activas
  /// del operario (bajas, vacaciones, paternidad).
  /// Se usan para justificar los dias sin parte: si un operario esta
  /// de baja, es normal que no tenga partes esos dias.
  final List<AusenciaLaboral> ausenciasActivas;

  /// Total de dias laborables en el periodo analizado.
  /// Ej: si el mes tiene 22 dias laborables (lunes a viernes),
  /// este campo vale 22. Sirve para calcular porcentajes de presencia
  /// y para que el gestor sepa cuantos partes deberia haber.
  final int totalLaborables;

  /// Conjunto (Set) de fechas que el gestor ha habilitado expresamente
  /// para que este operario pueda editar/crear partes de esos dias,
  /// aunque no sean el dia de hoy.
  ///
  /// Se usa Set en lugar de List porque:
  ///   - No importa el orden de las fechas.
  ///   - Se necesita busqueda rapida (contains) para saber si una
  ///     fecha concreta esta habilitada.
  ///   - No puede haber fechas duplicadas.
  ///
  /// Ej: {'2024-01-18', '2024-01-19'} (el gestor habilito esos dias
  /// para que el operario pueda rellenar partes pendientes).
  final Set<String> fechasHabilitadas;

  // --------------------------------------------------------------------------
  // CONSTRUCTOR
  // --------------------------------------------------------------------------

  /// Constructor de AusenciaInfo.
  /// Marcado como "const" porque todos los campos son final y pueden
  /// ser constantes si los parametros lo son.
  ///
  /// PARAMETROS:
  ///   [perfilId] - ID del operario (requerido).
  ///   [nombre] - Nombre del operario (requerido).
  ///   [diasSin] - Lista de dias sin parte (requerido).
  ///   [diasIncompletos] - Lista de dias incompletos (requerido).
  ///   [ausenciasActivas] - Lista de ausencias activas (requerido).
  ///   [totalLaborables] - Total dias laborables (requerido).
  ///   [fechasHabilitadas] - Set de fechas habilitadas (default vacio).
  const AusenciaInfo({
    required this.perfilId,
    required this.nombre,
    required this.diasSin,
    required this.diasIncompletos,
    required this.ausenciasActivas,
    required this.totalLaborables,
    this.fechasHabilitadas = const {},
  });

  // --------------------------------------------------------------------------
  // GETTERS CALCULADOS
  // --------------------------------------------------------------------------

  /// GETTER: totalIncidencias
  ///
  /// QUE HACE:
  ///   Calcula el numero total de incidencias de presencia para este
  ///   operario. Una incidencia es cualquier dia en el que algo no esta
  ///   correcto (falta el parte o las horas son insuficientes).
  ///
  /// FORMULA:
  ///   totalIncidencias = diasSinParte + diasIncompletos
  ///
  /// NOTA:
  ///   Las ausencias activas NO se cuentan como incidencias porque son
  ///   justificadas. Si un operario esta de baja, es normal que no tenga
  ///   partes esos dias.
  ///
  /// VALOR DE RETORNO:
  ///   int con la suma de dias sin parte y dias incompletos.
  int get totalIncidencias => diasSin.length + diasIncompletos.length;

  /// GETTER: soloAusencias
  ///
  /// QUE HACE:
  ///   Determina si el operario tiene solo ausencias justificadas y
  ///   ningun dia sin parte ni dia incompleto.
  ///
  /// PARA QUE SIRVE:
  ///   Si un operario solo tiene ausencias (ej: esta toda la semana de
  ///   baja), no hay incidencias reales que revisar. Este flag permite
  ///   al gestor filtrar y centrarse en los casos que requieren atencion.
  ///
  /// LOGICA:
  ///   - diasSin.isEmpty: no tiene dias sin parte (todos los partes
  ///     estan rellenados).
  ///   - diasIncompletos.isEmpty: no tiene dias con horas insuficientes.
  ///   - ausenciasActivas.isNotEmpty: tiene al menos una ausencia activa.
  ///
  /// VALOR DE RETORNO:
  ///   true si el operario solo tiene ausencias (sin otras incidencias).
  bool get soloAusencias =>
      diasSin.isEmpty && diasIncompletos.isEmpty && ausenciasActivas.isNotEmpty;

  // --------------------------------------------------------------------------
  // FACTORY CONSTRUCTOR: fromJson
  // --------------------------------------------------------------------------

  /// FACTORY: AusenciaInfo.fromJson
  ///
  /// QUE HACE:
  ///   Construye un objeto AusenciaInfo completo desde el JSON del
  ///   servidor. Ademas de los campos simples, convierte las listas
  ///   de objetos anidados (diasIncompletos, ausenciasActivas).
  ///
  /// PARAMETROS:
  ///   [json] - `Map<String, dynamic>` con los datos de incidencias.
  ///            El servidor devuelve listas de objetos anidados para
  ///            los dias incompletos y las ausencias activas.
  ///   [habilitadas] - `Set<String>` opcional con las fechas que el gestor
  ///                   ha habilitado para este operario. Se pasa por
  ///                   separado porque viene de otro endpoint.
  ///
  /// LOGICA INTERNA:
  ///
  ///   perfilId, nombre, totalLaborables:
  ///     Se extraen directamente como String/int.
  ///
  ///   diasSin:
  ///     Es una lista de strings. `List<String>.from()` convierte la lista
  ///     dinamica del JSON a una lista tipada de Dart. Si es null, usa [].
  ///
  ///   diasIncompletos:
  ///     Es una lista de objetos. Se castea a `List<dynamic>`, se recorre
  ///     con .map() y se convierte cada elemento a DiaIncompleto llamando
  ///     a su propio fromJson. El resultado se convierte a List con toList().
  ///
  ///   ausenciasActivas:
  ///     Misma logica que diasIncompletos pero con AusenciaLaboral.
  ///
  ///   fechasHabilitadas:
  ///     Se asigna directamente el parametro [habilitadas] que viene
  ///     del gestor (no del JSON de incidencias).
  ///
  /// VALOR DE RETORNO:
  ///   Nueva instancia de AusenciaInfo con todos los datos poblados.
  factory AusenciaInfo.fromJson(
    Map<String, dynamic> json, [
    Set<String> habilitadas = const {},
  ]) {
    return AusenciaInfo(
      // ID del perfil del operario
      perfilId: json['perfilId'] as String,
      // Nombre del operario (texto plano)
      nombre: json['nombre'] as String,
      // Lista de fechas sin parte (strings), vacio si es null
      diasSin: List<String>.from(json['diasSin'] ?? []),
      // Lista de objetos DiaIncompleto: se mapea cada elemento JSON
      diasIncompletos: (json['diasIncompletos'] as List<dynamic>? ?? [])
          // Cada elemento del JSON se convierte a DiaIncompleto
          .map((e) => DiaIncompleto.fromJson(e as Map<String, dynamic>))
          .toList(),
      // Lista de objetos AusenciaLaboral: misma logica que arriba
      ausenciasActivas: (json['ausenciasActivas'] as List<dynamic>? ?? [])
          .map((e) => AusenciaLaboral.fromJson(e as Map<String, dynamic>))
          .toList(),
      // Total de dias laborables en el periodo, 0 si es null
      totalLaborables: json['totalLaborables'] as int? ?? 0,
      // Fechas habilitadas (vienen por separado, no del JSON)
      fechasHabilitadas: habilitadas,
    );
  }
}

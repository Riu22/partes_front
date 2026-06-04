/// ============================================================================
/// MODELO: ParteTrabajo
/// ============================================================================
///
/// QUE REPRESENTA:
///   Este modelo representa un "parte de trabajo" o "reporte diario" que un
///   operario (electricista, fontanero, albanil, etc.) rellena al final de su
///   jornada laboral. Es el corazon del sistema.
///
/// ANALOGIA DEL MUNDO REAL:
///   Imagina una hoja de papel que cada trabajador debe llenar cada dia antes
///   de irse a casa. En esa hoja escribe:
///     - En que obra estuvo trabajando (cliente, direccion, etc.)
///     - Su nombre completo
///     - La fecha de hoy
///     - Cuantas horas trabajo (lo normal son 8 horas)
///     - Una descripcion de las tareas que realizo
///     - Si hizo trabajos extra (horas extra, materiales especiales, etc.)
///     - La especialidad con la que trabajo (ELECTRICIDAD, FONTANERIA, etc.)
///
///   Adicionalmente, este parte puede incluir la firma del cliente como
///   comprobante de que el trabajo fue realizado y aceptado. La firma se
///   guarda como una imagen (URL) en el servidor.
///
///   Tambien existe el concepto de "post-venta": cuando un trabajo ya
///   facturado requiere una visita adicional por algun ajuste o reparacion.
///   En ese caso, el parte se marca como "esPostVenta = true".
///
/// PROPOSITO EN LA APP:
///   Los partes de trabajo son la unidad basica de informacion para:
///     1. Calcular nomina de los operarios (multiplicar horas x tarifa).
///     2. Facturar a los clientes (horas trabajadas en su obra).
///     3. Llevar un historico de que se hizo, cuando y quien lo hizo.
///     4. Control de presencia: saber si un operario falto o trabajo menos
///        horas de las debidas.
///
/// ESTRUCTURA EN DART:
///   Es una clase "inmutable" (todos los campos son final) que solo almacena
///   datos. No tiene logica de negocio pesada, solo metodos de utilidad para
///   formatear informacion y validar si se puede editar.
///
///   Incluye un factory constructor "fromJson" que parsea la respuesta JSON
///   del servidor. Los nombres de los campos en JSON estan en espanol
///   (ej: "horas_normales", "creado_por_gestor") porque es como los envia
///   la API.
///
/// ============================================================================
class ParteTrabajo {
  // --------------------------------------------------------------------------
  // CAMPOS (PROPIEDADES)
  // --------------------------------------------------------------------------

  /// Identificador unico del parte en la base de datos del servidor.
  /// Es un numero entero auto-incremental que asigna el backend.
  /// Se usa como clave primaria para referenciar este parte en otras tablas.
  final int id;

  /// ID de la obra a la que pertenece este parte (opcional).
  /// Puede ser null si el parte no esta asociado a ninguna obra concreta,
  /// por ejemplo en trabajos administrativos o de oficina.
  /// Almacena solo el ID numerico; el nombre se guarda por separado
  /// en [obraNombre] para no tener que hacer otra peticion al servidor.
  final int? obraId;

  /// Nombre legible de la obra (ej: "Reforma Calle Mayor 123").
  /// Se guarda directamente aqui (desnormalizado) para evitar tener que
  /// cargar el objeto Obra completo cada vez que se muestra un parte.
  /// Si el parte no tiene obra, se muestra "Sin obra".
  final String obraNombre;

  /// Nombre de pila del operario (ej: "Juan").
  /// Se almacena directamente en el parte (desnormalizado) para rapidez
  /// en las listas y reportes, sin necesidad de consultar el perfil.
  final String operarioNombre;

  /// Apellidos del operario (ej: "Garcia Lopez").
  /// Se separa del nombre para poder formatear "Apellidos, Nombre"
  /// en los listados donde se ordena alfabeticamente por apellido.
  /// Si esta vacio, el getter [operarioNombreCompleto] solo devuelve el nombre.
  final String operarioApellidos;

  /// Fecha en la que se realizo el trabajo.
  /// Es un objeto DateTime de Dart. Almacena ano, mes y dia.
  /// La hora se ignora (siempre 00:00:00) porque el parte es diario.
  /// Se usa para ordenar partes cronologicamente y para filtrar por rango
  /// de fechas en la exportacion a PDF.
  final DateTime fecha;

  /// Horas normales trabajadas (tipicamente 8.0).
  /// Es un double para permitir fracciones (ej: 4.5 horas = media jornada).
  /// No incluye horas extra; esas van en [trabajosExtra] como texto libre.
  /// Se usa para calculos de nomina: horasNormales * tarifaPorHora.
  final double horasNormales;

  /// Descripcion textual de las tareas realizadas (campo obligatorio).
  /// El operario escribe aqui en lenguaje natural que hizo durante la jornada:
  /// "Instalacion de 5 tomas de corriente en salon", "Reparacion de fuga
  /// en bano principal", etc. Es el contenido principal del parte.
  final String descripcion;

  /// Especialidad con la que se trabajo (ej: "ELECTRICIDAD", "FONTANERIA").
  /// Es opcional porque un operario puede tener varias especialidades y
  /// no siempre se registra cual uso. Cuando tiene valor, se usa para
  /// filtrar partes por tipo de trabajo en los reportes de contabilidad.
  final String? especialidad;

  /// ID del perfil/operario en el sistema (String UUID o similar).
  /// Es opcional (puede ser null) para partes muy antiguos que no tenian
  /// esta asociacion. Sirve para enlazar el parte con el perfil completo
  /// del operario (email, rol, grupo profesional, etc.).
  final String? operarioId;

  /// Indica si el parte fue creado por un gestor (jefe, administrador)
  /// en lugar de por el propio operario.
  /// Cuando es true, significa que un gestor introdujo el parte manualmente
  /// porque el operario no pudo hacerlo (olvido, problema tecnico, etc.).
  /// Se usa para auditoria y control.
  /// En JSON viene como booleano o como entero (0/1), por eso la logica
  /// en fromJson comprueba ambos casos.
  final bool creadoPorGestor;

  /// URL de la imagen de la firma del cliente en el servidor.
  /// Es opcional porque no todos los partes requieren firma.
  /// La imagen se genera en la app (el cliente firma en la pantalla tactil)
  /// y se sube al servidor, que devuelve esta URL para recuperarla despues.
  final String? firmaUrl;

  /// Nombre de la persona que firmo el parte (opcional).
  /// Aunque la URL de la firma ya existe, se guarda el nombre para
  /// mostrarlo en informes sin tener que cargar la imagen.
  /// Ejemplo: "Maria Rodriguez" (la clienta que firmo).
  final String? nombreFirma;

  /// Indica si este parte corresponde a un trabajo de post-venta.
  /// Post-venta significa que el trabajo original ya fue facturado y
  /// entregado, pero el cliente requiere una visita adicional por
  /// garantia, ajuste o reparacion. Estos partes se facturan aparte
  /// o no se facturan (si estan en garantia).
  /// En JSON puede venir como booleano o entero para compatibilidad.
  final bool esPostVenta;

  /// Descripcion textual de trabajos extra realizados (opcional).
  /// Aqui se detallan horas extra, materiales especiales no previstos,
  /// desplazamientos largos, etc. Es texto libre, no estructurado.
  /// Se usa en la facturacion para anadir cargos adicionales.
  final String trabajosExtra;

  // --------------------------------------------------------------------------
  // CONSTRUCTOR PRINCIPAL
  // --------------------------------------------------------------------------

  /// Constructor principal de la clase.
  /// Todos los parametros son "required" (obligatorios) excepto los que
  /// tienen valor por defecto. Esto asegura que nadie cree un ParteTrabajo
  /// incompleto.
  ///
  /// PARAMETROS:
  ///   [id] - ID unico (requerido, sin default).
  ///   [obraId] - ID de la obra (opcional, null por defecto).
  ///   [obraNombre] - Nombre de la obra (requerido, sin default).
  ///   [operarioNombre] - Nombre del operario (requerido, sin default).
  ///   [operarioApellidos] - Apellidos del operario (default '').
  ///   [fecha] - Fecha del parte (requerido, sin default).
  ///   [horasNormales] - Horas trabajadas (requerido, sin default).
  ///   [descripcion] - Tareas realizadas (requerido, sin default).
  ///   [especialidad] - Especialidad usada (opcional, null por defecto).
  ///   [operarioId] - ID del perfil (opcional, null por defecto).
  ///   [creadoPorGestor] - Creado por gestor (default false).
  ///   [firmaUrl] - URL de la firma (opcional, null por defecto).
  ///   [nombreFirma] - Nombre del firmante (opcional, null por defecto).
  ///   [esPostVenta] - Es trabajo post-venta (default false).
  ///   [trabajosExtra] - Trabajos extra (default '').
  ParteTrabajo({
    required this.id,
    this.obraId,
    required this.obraNombre,
    required this.operarioNombre,
    this.operarioApellidos = '',
    required this.fecha,
    required this.horasNormales,
    required this.descripcion,
    this.especialidad,
    this.operarioId,
    this.creadoPorGestor = false,
    this.firmaUrl,
    this.nombreFirma,
    this.esPostVenta = false,
    this.trabajosExtra = '',
  });

  // --------------------------------------------------------------------------
  // GETTERS (PROPIEDADES CALCULADAS)
  // --------------------------------------------------------------------------

  /// GETTER: operarioNombreCompleto
  ///
  /// QUE HACE:
  ///   Devuelve el nombre completo del operario formateado como
  ///   "Apellidos, Nombre" (ej: "Garcia Lopez, Juan").
  ///
  /// POR QUE ES UTIL:
  ///   En los listados y reportes se suele mostrar el operario con el
  ///   apellido primero para ordenar alfabeticamente. Este getter evita
  ///   repetir la logica de formateo en toda la app.
  ///
  /// LOGICA INTERNA:
  ///   1. Limpia espacios al inicio/final de apellidos y nombre.
  ///   2. Si no hay apellidos (vacio), devuelve solo el nombre.
  ///   3. Si hay apellidos, los pone primero separados por coma y espacio.
  ///
  /// VALOR DE RETORNO:
  ///   String con el nombre formateado. Nunca es null.
  String get operarioNombreCompleto {
    // Quita espacios extra al inicio y final de los apellidos
    final ap = operarioApellidos.trim();
    // Quita espacios extra al inicio y final del nombre
    final nm = operarioNombre.trim();
    // Si el apellido esta vacio, devolvemos solo el nombre (caso raro)
    if (ap.isEmpty) return nm;
    // Formato estandar: "Apellidos, Nombre"
    return '$ap, $nm';
  }

  // --------------------------------------------------------------------------
  // FACTORY CONSTRUCTOR: fromJson (DESERIALIZACION)
  // --------------------------------------------------------------------------

  /// FACTORY: ParteTrabajo.fromJson
  ///
  /// QUE HACE:
  ///   Construye un objeto ParteTrabajo a partir de un mapa JSON que devuelve
  ///   el servidor. Es el metodo inverso a la serializacion (convertir objeto
  ///   a JSON para enviar al servidor).
  ///
  /// POR QUE ES UN FACTORY:
  ///   En Dart, un factory constructor permite devolver una instancia existente
  ///   o crear una nueva con logica adicional. Aqui se usa para parsear los
  ///   campos del mapa JSON y construir un ParteTrabajo con ellos.
  ///
  /// PARAMETROS:
  ///   [json] - `Map<String, dynamic>` que contiene los datos del parte.
  ///            Los campos vienen en espanol porque asi los envia la API.
  ///
  /// LOGICA INTERNA POR CAMPO:
  ///
  ///   id:
  ///     Se toma directamente del JSON. Es un entero simple.
  ///
  ///   obraId:
  ///     Viene anidado dentro de "obra" como un objeto: {"id": 5, ...}.
  ///     Accedemos con json['obra']?['id']. El operador '?' (null-aware)
  ///     evita un error si 'obra' es null.
  ///
  ///   obraNombre:
  ///     Similar, viene de json['obra']?['nombre']. Si es null, usamos
  ///     "Sin obra" como valor por defecto con el operador ??.
  ///
  ///   operarioNombre:
  ///     Viene dentro de "perfil": {"name": "Juan", ...}.
  ///     Nota: en el servidor el campo se llama "name" (ingles), no "nombre".
  ///     Si falta, usamos "Sin nombre".
  ///
  ///   operarioApellidos:
  ///     Tambien dentro de "perfil" como "apellidos". Default ''.
  ///
  ///   fecha:
  ///     Viene como string ISO 8601 (ej: "2024-01-15"). DateTime.parse
  ///     lo convierte a objeto DateTime. Si el formato es invalido, lanza
  ///     una excepcion (por eso el servidor debe enviarlo siempre correcto).
  ///
  ///   horasNormales:
  ///     Viene como numero (int o double). Con (json[...] ?? 8.0) aseguramos
  ///     que si falta el campo, se usen 8 horas por defecto. toDouble()
  ///     convierte a double aunque el JSON traiga un entero.
  ///
  ///   descripcion:
  ///     Texto libre. Default '' si es null.
  ///
  ///   especialidad:
  ///     Puede ser null si el parte no especifica especialidad.
  ///
  ///   operarioId:
  ///     Viene de "perfil" como "id". Puede ser null.
  ///
  ///   creadoPorGestor:
  ///     Puede venir como booleano (true/false) o como entero (1/0).
  ///     Por eso comprobamos ambos: == true para booleano, == 1 para entero.
  ///
  ///   firmaUrl:
  ///     URL string, puede ser null si no hay firma.
  ///
  ///   nombreFirma:
  ///     Nombre del firmante, puede ser null.
  ///
  ///   esPostVenta:
  ///     Igual que creadoPorGestor: admite booleano o entero (1/0).
  ///
  ///   trabajosExtra:
  ///     Texto libre. Default ''.
  ///
  /// VALOR DE RETORNO:
  ///   Una nueva instancia de ParteTrabajo con todos los campos poblados.
  factory ParteTrabajo.fromJson(Map<String, dynamic> json) => ParteTrabajo(
    // -- Campo directo: id del parte --
    id: json['id'],
    // -- Obra: objeto anidado con id y nombre --
    obraId: json['obra']?['id'],
    // Si obra es null o no tiene nombre, se asigna "Sin obra"
    obraNombre: json['obra']?['nombre'] ?? 'Sin obra',
    // -- Perfil/operario: objeto anidado --
    // El servidor usa "name" (ingles) como nombre de pila
    operarioNombre: json['perfil']?['name'] ?? 'Sin nombre',
    // Apellidos en el mismo objeto perfil
    operarioApellidos: json['perfil']?['apellidos'] ?? '',
    // -- Fecha: string ISO a DateTime --
    fecha: DateTime.parse(json['fecha']),
    // Horas normales, por defecto 8 si no viene el campo
    horasNormales: (json['horas_normales'] ?? 8.0).toDouble(),
    // Descripcion de tareas, default cadena vacia
    descripcion: json['descripcion'] ?? '',
    // Especialidad (opcional, puede ser null)
    especialidad: json['especialidad'],
    // ID del perfil (opcional)
    operarioId: json['perfil']?['id'],
    // Compatibilidad booleano/entero para creado_por_gestor
    creadoPorGestor:
        json['creado_por_gestor'] == true || json['creado_por_gestor'] == 1,
    // URL de la firma (opcional)
    firmaUrl: json['firma_url'],
    // Nombre de la persona que firmo (opcional)
    nombreFirma: json['nombre_firmado'],
    // Compatibilidad booleano/entero para es_post_venta
    esPostVenta: json['es_post_venta'] == true || json['es_post_venta'] == 1,
    // Trabajos extra (texto libre, default '')
    trabajosExtra: json['trabajos_extra'] ?? '',
  );

  // --------------------------------------------------------------------------
  // GETTERS DE VALIDACION
  // --------------------------------------------------------------------------

  /// GETTER: puedeEditarse
  ///
  /// QUE HACE:
  ///   Determina si este parte de trabajo puede ser editado.
  ///
  /// REGLA DE NEGOCIO:
  ///   Por politica de la empresa, un parte solo se puede modificar si es
  ///   del dia de hoy. Esto evita que los operarios modifiquen partes
  ///   antiguos (lo que falsificaria el registro historico).
  ///
  /// LOGICA INTERNA:
  ///   Compara el ano, mes y dia de la fecha del parte con la fecha actual
  ///   del dispositivo (DateTime.now()). Si coinciden las tres componentes,
  ///   el parte es de hoy y puede editarse.
  ///
  ///   NOTA: Usa la fecha local del dispositivo, no la del servidor.
  ///   Esto significa que si el usuario cambia la fecha de su telefono,
  ///   podria editar partes de otros dias. Es una limitacion conocida.
  ///
  /// VALOR DE RETORNO:
  ///   bool: true si el parte es de hoy, false en caso contrario.
  bool get puedeEditarse {
    // Obtiene la fecha y hora actual del sistema
    final hoy = DateTime.now();
    // Compara ano, mes y dia por separado (ignora hora, minuto, segundo)
    return fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
  }

  /// METODO: puedeEditarseConFechas
  ///
  /// QUE HACE:
  ///   Version extendida de [puedeEditarse] que tambien permite editar
  ///   si el gestor ha habilitado expresamente ciertas fechas para este
  ///   operario.
  ///
  /// CUANDO SE USA:
  ///   El gestor puede habilitar dias concretos (ej: los ultimos 5 dias
  ///   del mes) para que los operarios puedan rellenar o corregir partes
  ///   de esos dias aunque no sean hoy. Esto es util cuando:
  ///     - El operario estuvo de vacaciones y no pudo rellenar a tiempo.
  ///     - Hubo un error y el parte se relleno mal.
  ///     - Se necesita cerrar la nomina mensual.
  ///
  /// PARAMETROS:
  ///   [fechasPermitidas] - `List<DateTime>` con las fechas que el gestor
  ///                        ha habilitado. Cada elemento es un dia concreto
  ///                        que se puede editar.
  ///
  /// LOGICA INTERNA:
  ///   1. Primero comprueba si el parte es de hoy (puedeEditarse). Si lo
  ///      es, devuelve true inmediatamente sin revisar la lista.
  ///   2. Si no es de hoy, recorre la lista de fechas permitidas y compara
  ///      cada una con la fecha del parte (solo ano, mes, dia).
  ///   3. Si alguna coincide, devuelve true (se puede editar).
  ///   4. Si ninguna coincide, devuelve false.
  ///
  ///   Usa el metodo "any" de Dart que recorre la lista y devuelve true
  ///   en cuanto encuentra una coincidencia (corto circuito), lo que es
  ///   eficiente para listas grandes.
  ///
  /// VALOR DE RETORNO:
  ///   bool: true si el parte es de hoy O si la fecha esta en la lista
  ///         de fechas permitidas. false en caso contrario.
  bool puedeEditarseConFechas(List<DateTime> fechasPermitidas) {
    // Si ya es de hoy, no hace falta mirar la lista
    if (puedeEditarse) return true;
    // Recorre la lista buscando una fecha que coincida con la del parte
    return fechasPermitidas.any(
      (f) =>
          // Compara solo ano, mes y dia (ignora hora)
          f.year == fecha.year && f.month == fecha.month && f.day == fecha.day,
    );
  }
}

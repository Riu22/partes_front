/// ============================================================================
/// MODELO: Obra
/// ============================================================================
///
/// QUE REPRESENTA:
///   Este modelo representa una obra de construccion, reforma o instalacion.
///   Es el lugar fisico donde los operarios realizan su trabajo.
///
/// ANALOGIA DEL MUNDO REAL:
///   Imagina una carpeta fisica de proyecto que contiene toda la informacion
///   de un trabajo: direccion, codigo de proyecto, si esta en curso o ya se
///   termino. Cada obra es como un "expediente" que agrupa todos los partes
///   de trabajo (ParteTrabajo) de los operarios que trabajaron ahi.
///
///   Ejemplos concretos:
///     - "Reforma integral Calle Mayor 123" (obra de gran envergadura)
///     - "Instalacion electrica nave industrial Poligono Sur" (obra especifica)
///     - "Mantenimiento mensual Edificio Torres" (obra recurrente)
///
/// RELACION CON OTROS MODELOS:
///   - Una Obra tiene muchos ParteTrabajo asociados (relacion 1:N).
///   - Un Perfil (operario) puede trabajar en muchas Obras.
///   - En contabilidad, las horas se agrupan por Obra.
///
/// ESTRUCTURA EN DART:
///   Clase simple con 6 campos obligatorios. Incluye un flag "activa" para
///   saber si la obra esta en curso (true) o finalizada (false).
///   Tiene un factory constructor fromJson para deserializar desde la API.
///
/// ============================================================================
class Obra {
  // --------------------------------------------------------------------------
  // CAMPOS (PROPIEDADES)
  // --------------------------------------------------------------------------

  /// Identificador unico de la obra en la base de datos del servidor.
  /// Es un numero entero auto-incremental. Se usa como clave primaria
  /// para asociar partes de trabajo, facturas, etc.
  final int id;

  /// Nombre comercial o descriptivo de la obra.
  /// Ej: "Reforma Calle Mayor 123", "Instalacion Nave Poligono".
  /// Es el campo que se muestra en las listas desplegables y en los
  /// partes de trabajo. Debe ser unico o al menos identificable.
  final String nombre;

  /// Direccion o ubicacion geografica de la obra (calle, numero, etc.).
  /// Ej: "Calle Mayor, 123, 2o B". Es texto libre, sin formato fijo.
  /// Se usa en informes y facturas para identificar donde se trabajo.
  final String ubicacion;

  /// Municipio donde se encuentra la obra (ej: "Madrid", "Barcelona").
  /// Separado de [ubicacion] para poder filtrar o agrupar obras por
  /// localidad en los reportes de contabilidad y planificacion.
  final String municipio;

  /// Poblacion o nucleo urbano (puede coincidir con [municipio] o ser
  /// una pedania/barrio). Ej: "Vallecas", "Carabanchel".
  /// Se usa para informes mas detallados de localizacion.
  final String poblacion;

  /// Codigo interno de la empresa para la obra (ej: "OBR-2024-00123").
  /// Es un identificador administrativo usado en facturacion y
  /// contabilidad. No debe confundirse con [id] que es el de la BD.
  final String codigo;

  /// Indica si la obra esta activa (en curso) o inactiva (finalizada).
  /// Las obras inactivas no aparecen en los menus de seleccion para
  /// nuevos partes de trabajo, pero si en el historico.
  /// Por defecto en fromJson se asume true si falta el campo.
  final bool activa;

  // --------------------------------------------------------------------------
  // CONSTRUCTOR PRINCIPAL
  // --------------------------------------------------------------------------

  /// Constructor principal de la clase Obra.
  ///
  /// PARAMETROS:
  ///   [id] - ID unico de la obra (requerido, int).
  ///   [nombre] - Nombre descriptivo (requerido).
  ///   [ubicacion] - Direccion fisica (requerido).
  ///   [poblacion] - Poblacion/barrio (requerido).
  ///   [municipio] - Municipio/localidad (requerido).
  ///   [codigo] - Codigo interno administrativo (requerido).
  ///   [activa] - Estado actual: true = en curso, false = finalizada.
  Obra({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.poblacion,
    required this.municipio,
    required this.codigo,
    required this.activa,
  });

  // --------------------------------------------------------------------------
  // FACTORY CONSTRUCTOR: fromJson (DESERIALIZACION)
  // --------------------------------------------------------------------------

  /// FACTORY: Obra.fromJson
  ///
  /// QUE HACE:
  ///   Construye un objeto Obra a partir del mapa JSON devuelto por el
  ///   servidor. Convierte cada campo del JSON (strings, ints, bools)
  ///   a los tipos Dart correspondientes.
  ///
  /// PARAMETROS:
  ///   [json] - `Map<String, dynamic>` con los datos de la obra.
  ///            Los nombres de campo estan en espanol porque la API
  ///            los envia asi (ej: "nombre", "ubicacion", "activa").
  ///
  /// LOGICA INTERNA:
  ///   - Para campos String: se fuerza la conversion con "as String?"
  ///     y si es null se usa '' (cadena vacia) con el operador ??.
  ///   - Para campos int: se fuerza con "as int".
  ///   - Para campos bool: se fuerza con "as bool?" y si es null se
  ///     asume true (obra activa por defecto).
  ///
  ///   El operador "as" en Dart hace casting de tipo. Si el tipo no
  ///   coincide, lanza una excepcion en tiempo de ejecucion. El "?"
  ///   despues del tipo (ej: String?) permite que sea null y no lance
  ///   error si el campo no existe en el JSON.
  ///
  /// VALOR DE RETORNO:
  ///   Una nueva instancia de Obra con todos los campos poblados.
  factory Obra.fromJson(Map<String, dynamic> json) => Obra(
    // Campo id: se espera que sea int, si no lanza excepcion
    id: json['id'] as int,
    // Campo nombre: String o null. Si null, cadena vacia.
    nombre: json['nombre'] as String? ?? '',
    // Campo ubicacion: String o null. Si null, cadena vacia.
    ubicacion: json['ubicacion'] as String? ?? '',
    // Campo municipio: String o null. Si null, cadena vacia.
    municipio: json['municipio'] as String? ?? '',
    // Campo poblacion: String o null. Si null, cadena vacia.
    poblacion: json['poblacion'] as String? ?? '',
    // Campo codigo: String o null. Si null, cadena vacia.
    codigo: json['codigo'] as String? ?? '',
    // Campo activa: bool o null. Si null, se asume true (activa).
    activa: json['activa'] as bool? ?? true,
  );
}

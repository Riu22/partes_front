/// ============================================================================
/// MODELO: Perfil
/// ============================================================================
///
/// QUE REPRESENTA:
///   Este modelo representa el perfil de un usuario del sistema. Un usuario
///   puede ser un operario (trabajador de campo), un encargado (supervisor
///   de obras), un jefe de obra, un gestor (administrativo), o un
///   administrador del sistema.
///
/// ANALOGIA DEL MUNDO REAL:
///   Es como la ficha personal de cada empleado en la empresa. En esa ficha
///   constan:
///     - Datos personales: nombre, apellidos, email.
///     - Cargo o rol: que puesto ocupa y que permisos tiene.
///     - Especialidad: de que area es (electricidad, fontaneria, etc.).
///     - Codigo de empleado: identificador interno de RRHH.
///     - Grupo profesional: categoria segun el convenio colectivo.
///     - Estado: si esta activo (trabajando) o inactivo (baja, excedencia).
///     - Postventa: si esta autorizado a hacer trabajos de post-venta.
///
/// JERARQUIA DE ROLES (de mayor a menor privilegio):
///   1. ADMINISTRACION   - Acceso total al sistema.
///   2. GESTION          - Gestion operativa y reportes.
///   3. JEFE_DE_OBRA     - Supervisa obras asignadas.
///   4. ENCARGADO        - Encargado de una o varias obras.
///   5. OPERARIO         - Trabajador de campo (menos privilegios).
///
/// PROPOSITO EN LA APP:
///   El perfil determina:
///     - Que pantallas puede ver el usuario (navegacion).
///     - Que acciones puede hacer (crear partes, validar, eliminar, etc.).
///     - Que datos puede ver (nivel de acceso: TOTAL, ZONA, OBRA, INDIVIDUAL).
///
/// ESTRUCTURA EN DART:
///   Clase con campos basicos de perfil + metodos para:
///     - Formatear nombre (nombre completo, apellido+nombre).
///     - Deserializar desde JSON (fromJson).
///     - Convertir a mapa (toMap) para pasar a pantallas de edicion.
///     - Consultar rol (esAdmin, esGestion, etc.).
///     - Consultar permisos (puedeVerEquipos, puedeValidar, etc.).
///     - Obtener nivel de acceso (nivelAcceso).
///
/// ============================================================================
class Perfil {
  // --------------------------------------------------------------------------
  // CAMPOS (PROPIEDADES)
  // --------------------------------------------------------------------------

  /// Identificador unico del perfil en el sistema.
  /// A diferencia de ParteTrabajo.id que es un entero auto-incremental,
  /// este es un String (posiblemente un UUID o un ID generado por
  /// Firebase/Supabase). Se usa para relacionar con otras entidades.
  final String id;

  /// Direccion de correo electronico del usuario.
  /// Se usa para inicio de sesion, notificaciones y recuperacion de
  /// contrasena. En el sistema, el email es unico por usuario.
  final String email;

  /// Nombre de pila del usuario (ej: "Juan", "Maria").
  /// No incluye los apellidos, que van en el campo [apellidos].
  final String nombre;

  /// Apellidos del usuario (ej: "Garcia Lopez").
  /// Se almacenan separados del nombre para poder formatear como
  /// "Apellidos, Nombre" en los listados ordenados alfabeticamente.
  final String apellidos;

  /// Rol del usuario dentro de la jerarquia de la empresa.
  /// Los valores posibles son:
  ///   - 'ADMINISTRACION'  (maximos permisos)
  ///   - 'GESTION'         (permisos altos)
  ///   - 'JEFE_DE_OBRA'    (permisos medios-altos)
  ///   - 'ENCARGADO'       (permisos medios)
  ///   - 'OPERARIO'        (permisos minimos)
  /// Este string se usa en los metodos de verificacion de rol
  /// (esAdmin, esGestion, etc.) para determinar que puede hacer el usuario.
  final String rol;

  /// Indica si el perfil esta activo en el sistema.
  /// Un perfil inactivo no puede iniciar sesion ni hacer ninguna accion.
  /// Se usa para dar de baja temporal a empleados (bajas laborales,
  /// excedencias, vacaciones largas) sin borrar sus datos historicos.
  final bool activo;

  /// Indica si el usuario esta autorizado para realizar trabajos de
  /// post-venta. La post-venta son visitas a clientes ya facturados
  /// para ajustes, reparaciones en garantia, etc. No todos los operarios
  /// tienen esta autorizacion.
  final bool postventa;

  /// Especialidad principal del operario (ej: "ELECTRICIDAD").
  /// Define el area de trabajo en la que el operario esta capacitado.
  /// Se usa para asignar operarios a obras que requieren esa especialidad.
  /// Por defecto es 'ELECTRICIDAD' si no se especifica.
  final String especialidad;

  /// Codigo interno de empleado asignado por RRHH (ej: "EMP-00123").
  /// Es un identificador administrativo independiente del [id] del sistema.
  /// Puede estar vacio si la empresa no asigna estos codigos.
  final String codigo;

  /// Grupo profesional segun el convenio colectivo aplicable.
  /// Ej: "OFICIAL_1A", "OFICIAL_2A", "AYUDANTE", "PEON".
  /// Determina la categoria salarial y los derechos laborales.
  /// Se usa en los modulos de nomina y contabilidad.
  final String grupoProfesional;

  // --------------------------------------------------------------------------
  // CONSTRUCTOR PRINCIPAL
  // --------------------------------------------------------------------------

  /// Constructor principal de Perfil.
  ///
  /// PARAMETROS:
  ///   [id] - ID del perfil (String, requerido).
  ///   [email] - Email del usuario (requerido).
  ///   [nombre] - Nombre de pila (requerido).
  ///   [apellidos] - Apellidos (requerido).
  ///   [rol] - Rol en la empresa (requerido).
  ///   [activo] - Estado activo/inactivo (requerido).
  ///   [postventa] - Autorizado para post-venta (default false).
  ///   [especialidad] - Especialidad (default 'ELECTRICIDAD').
  ///   [codigo] - Codigo de empleado (default '').
  ///   [grupoProfesional] - Grupo profesional (default '').
  Perfil({
    required this.id,
    required this.email,
    required this.nombre,
    required this.apellidos,
    required this.rol,
    required this.activo,
    this.postventa = false,
    this.especialidad = 'ELECTRICIDAD',
    this.codigo = '',
    this.grupoProfesional = '',
  });

  // --------------------------------------------------------------------------
  // GETTERS DE NOMBRES FORMATEADOS
  // --------------------------------------------------------------------------

  /// GETTER: nombreCompleto
  ///
  /// QUE HACE:
  ///   Devuelve el nombre completo del usuario en formato "Nombre Apellidos"
  ///   (ej: "Juan Garcia Lopez"). Se usa en las pantallas de perfil,
  ///   encabezados, saludos personalizados, etc.
  ///
  /// LOGICA INTERNA:
  ///   Concatena [nombre] y [apellidos] con un espacio, luego aplica trim()
  ///   para eliminar espacios sobrantes al inicio o final.
  ///
  /// VALOR DE RETORNO:
  ///   String. Nunca null, aunque puede devolver cadena vacia si ambos
  ///   campos estan vacios.
  String get nombreCompleto => '$nombre $apellidos'.trim();

  /// GETTER: nombreApellidoCompleto
  ///
  /// QUE HACE:
  ///   Devuelve el nombre completo con el apellido primero: "Apellidos, Nombre"
  ///   (ej: "Garcia Lopez, Juan"). Se usa en listados y tablas donde se
  ///   ordena alfabeticamente por apellido.
  ///
  /// VALOR DE RETORNO:
  ///   String con el formato "Apellidos, Nombre". Aplica trim() por seguridad.
  String get nombreApellidoCompleto => '$apellidos, $nombre'.trim();

  // --------------------------------------------------------------------------
  // FACTORY CONSTRUCTOR: fromJson (DESERIALIZACION)
  // --------------------------------------------------------------------------

  /// FACTORY: Perfil.fromJson
  ///
  /// QUE HACE:
  ///   Construye un objeto Perfil a partir del mapa JSON que devuelve
  ///   el servidor. Cada campo se extrae del mapa con valores por defecto
  ///   para evitar errores si faltan datos.
  ///
  /// PARAMETROS:
  ///   [json] - `Map<String, dynamic>` con los datos del perfil.
  ///            Los nombres de campo son mixtos: "name" (ingles) para el
  ///            nombre de pila, "apellidos" (espanol) para los apellidos.
  ///
  /// LOGICA INTERNA:
  ///   Usa el operador ?? para asignar valores por defecto cuando el
  ///   campo es null o no existe. Esto hace que el codigo sea tolerante
  ///   a cambios en la API (nuevos campos que faltan, etc.).
  ///
  /// VALOR DE RETORNO:
  ///   Una nueva instancia de Perfil.
  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      // ID: puede venir como String o numero, se fuerza a String
      id: json['id'] ?? '',
      // Email: string o vacio si falta
      email: json['email'] ?? '',
      // Nombre: el servidor usa "name" (ingles) en lugar de "nombre"
      nombre: json['name'] ?? '',
      // Apellidos: en espanol en la API
      apellidos: json['apellidos'] ?? '',
      // Rol: por defecto 'OPERARIO' si no se especifica
      rol: json['rol'] ?? 'OPERARIO',
      // Activo: por defecto true si falta el campo
      activo: json['activo'] ?? true,
      // Postventa: por defecto false
      postventa: json['postventa'] ?? false,
      // Especialidad: por defecto 'ELECTRICIDAD'
      especialidad: json['especialidad'] ?? 'ELECTRICIDAD',
      // Codigo de empleado: vacio por defecto
      codigo: json['codigo'] ?? '',
      // Grupo profesional: vacio por defecto
      grupoProfesional: json['grupo_profesional'] ?? '',
    );
  }

  /// METODO: toMap
  ///
  /// QUE HACE:
  ///   Convierte el objeto Perfil a un `Map<String, dynamic>` para pasarlo
  ///   como argumento a la pantalla de EditarUsuarioScreen. Este mapa
  ///   tiene el mismo formato que espera el widget de edicion de usuario.
  ///
  /// DIFERENCIA CON fromJson:
  ///   Mientras fromJson lee del servidor (que usa "name" para el nombre),
  ///   toMap genera un mapa para consumo interno de la app, manteniendo
  ///   el mismo nombre "name" por compatibilidad con el widget de edicion.
  ///
  /// VALOR DE RETORNO:
  ///   `Map<String, dynamic>` con las claves en el formato que espera el
  ///   widget de edicion. Las claves son: 'id', 'email', 'name', 'apellidos',
  ///   'rol', 'activo', 'postventa', 'especialidad', 'codigo',
  ///   'grupo_profesional'.
  Map<String, dynamic> toMap() {
    return {
      'id': id,                       // ID del perfil
      'email': email,                 // Email del usuario
      'name': nombre,                 // Nombre (clave "name" por compatibilidad)
      'apellidos': apellidos,         // Apellidos
      'rol': rol,                     // Rol en la empresa
      'activo': activo,               // Estado activo/inactivo
      'postventa': postventa,         // Autorizado post-venta
      'especialidad': especialidad,   // Especialidad
      'codigo': codigo,               // Codigo de empleado
      'grupo_profesional': grupoProfesional, // Grupo profesional
    };
  }

  // --------------------------------------------------------------------------
  // GETTERS DE VERIFICACION DE ROL
  // --------------------------------------------------------------------------
  //
  //  Jerarquia de roles (de mayor a menor privilegio):
  //    ADMINISTRACION > GESTION > JEFE_DE_OBRA > ENCARGADO > OPERARIO
  //
  //  Cada getter compara this.rol con el string del rol correspondiente.
  //  Se usan en toda la app para decidir que UI mostrar y que acciones
  //  permitir.
  // --------------------------------------------------------------------------

  /// GETTER: esAdmin
  ///
  /// QUE HACE:
  ///   Verifica si el usuario tiene rol de administracion.
  ///   Los administradores tienen acceso TOTAL al sistema: pueden ver
  ///   todo, editar todo, eliminar registros, gestionar usuarios, etc.
  ///
  /// VALOR DE RETORNO:
  ///   true si rol es exactamente 'ADMINISTRACION'.
  bool get esAdmin => rol == 'ADMINISTRACION';

  /// GETTER: esGestion
  ///
  /// QUE HACE:
  ///   Verifica si el usuario tiene rol de gestion.
  ///   Los gestores tienen permisos altos pero no pueden eliminar
  ///   registros ni gestionar usuarios (eso es solo admin).
  ///
  /// VALOR DE RETORNO:
  ///   true si rol es exactamente 'GESTION'.
  bool get esGestion => rol == 'GESTION';

  /// GETTER: esJefeObra
  ///
  /// QUE HACE:
  ///   Verifica si el usuario tiene rol de jefe de obra.
  ///   Los jefes de obra supervisan una zona o conjunto de obras.
  ///   Pueden ver los partes de sus obras asignadas y validarlos.
  ///
  /// VALOR DE RETORNO:
  ///   true si rol es exactamente 'JEFE_DE_OBRA'.
  bool get esJefeObra => rol == 'JEFE_DE_OBRA';

  /// GETTER: esEncargado
  ///
  /// QUE HACE:
  ///   Verifica si el usuario tiene rol de encargado.
  ///   Los encargados supervisan obras concretas sobre el terreno.
  ///   Pueden crear partes (si ellos tambien trabajan) y validar
  ///   los partes de los operarios a su cargo.
  ///
  /// VALOR DE RETORNO:
  ///   true si rol es exactamente 'ENCARGADO'.
  bool get esEncargado => rol == 'ENCARGADO';

  /// GETTER: esOperario
  ///
  /// QUE HACE:
  ///   Verifica si el usuario tiene rol de operario.
  ///   Los operarios son los trabajadores de campo que rellenan partes
  ///   de trabajo. Tienen los permisos mas restringidos: solo pueden
  ///   crear y ver sus propios partes.
  ///
  /// VALOR DE RETORNO:
  ///   true si rol es exactamente 'OPERARIO'.
  bool get esOperario => rol == 'OPERARIO';

  // --------------------------------------------------------------------------
  // GETTERS DE PERMISOS
  // --------------------------------------------------------------------------
  //
  //  Cada permiso se calcula en funcion del rol. Los roles superiores
  //  heredan los permisos de los inferiores. Por ejemplo, ADMINISTRACION
  //  tiene todos los permisos, mientras que OPERARIO tiene los minimos.
  // --------------------------------------------------------------------------

  /// GETTER: puedeVerEquipos
  ///
  /// QUE HACE:
  ///   Determina si el usuario puede ver la pantalla de equipos y
  ///   asignaciones de operarios a obras.
  ///
  /// QUIEN TIENE ACCESO:
  ///   Administracion, Gestion, Jefe de Obra y Encargado.
  ///   Los operarios NO pueden ver equipos (solo se ven a si mismos).
  ///
  /// VALOR DE RETORNO:
  ///   true si el rol tiene permiso para ver equipos.
  bool get puedeVerEquipos => esAdmin || esGestion || esJefeObra || esEncargado;

  /// GETTER: puedeValidar
  ///
  /// QUE HACE:
  ///   Determina si el usuario puede validar (aprobar/rechazar) partes
  ///   de trabajo de otros operarios. La validacion es el proceso de
  ///   revision y confirmacion de que el parte es correcto.
  ///
  /// QUIEN TIENE ACCESO:
  ///   Administracion, Gestion, Jefe de Obra y Encargado.
  ///   Los operarios NO pueden validar (solo crean sus propios partes).
  ///
  /// VALOR DE RETORNO:
  ///   true si el rol puede validar partes.
  bool get puedeValidar => esAdmin || esGestion || esJefeObra || esEncargado;

  /// GETTER: puedeCrearParte
  ///
  /// QUE HACE:
  ///   Determina si el usuario puede crear nuevos partes de trabajo.
  ///
  /// QUIEN TIENE ACCESO:
  ///   Operarios y Encargados. Los roles superiores (JefeObra, Gestion,
  ///   Admin) normalmente no crean partes; en su lugar usan la opcion
  ///   "creadoPorGestor" si necesitan hacerlo excepcionalmente.
  ///
  /// VALOR DE RETORNO:
  ///   true si el rol puede crear partes de trabajo.
  bool get puedeCrearParte => esOperario || esEncargado;

  /// GETTER: puedeEliminar
  ///
  /// QUE HACE:
  ///   Determina si el usuario puede eliminar partes de trabajo u otros
  ///   registros del sistema.
  ///
  /// RESTRICCION:
  ///   Solo los administradores pueden eliminar. Esto es una medida de
  ///   seguridad para evitar la perdida accidental de datos.
  ///
  /// VALOR DE RETORNO:
  ///   true solo si el rol es ADMINISTRACION.
  bool get puedeEliminar => esAdmin;

  /// GETTER: puedeGestionarUsuarios
  ///
  /// QUE HACE:
  ///   Determina si el usuario puede acceder a la pantalla de gestion
  ///   de usuarios (crear, editar, desactivar perfiles).
  ///
  /// RESTRICCION:
  ///   Solo los administradores pueden gestionar usuarios, ya que esto
  ///   implica cambios sensibles en la seguridad del sistema.
  ///
  /// VALOR DE RETORNO:
  ///   true solo si el rol es ADMINISTRACION.
  bool get puedeGestionarUsuarios => esAdmin;

  // --------------------------------------------------------------------------
  // GETTER: nivelAcceso
  // --------------------------------------------------------------------------

  /// GETTER: nivelAcceso
  ///
  /// QUE HACE:
  ///   Determina el nivel de acceso a datos que tiene el usuario segun
  ///   su rol. Esto controla que informacion se muestra en los reportes,
  ///   paneles y listados.
  ///
  /// NIVELES DE ACCESO:
  ///
  ///   TOTAL      - Admin y Gestion: ven absolutamente todos los datos
  ///                de todas las obras y todos los operarios.
  ///                Ej: un gestor ve el reporte global de la empresa.
  ///
  ///   ZONA       - Jefe de Obra: ven solo los datos de su zona o
  ///                conjunto de obras asignadas.
  ///                Ej: un jefe ve las obras de la zona norte.
  ///
  ///   OBRA       - Encargado: ven solo los datos de sus obras asignadas.
  ///                Ej: un encargado ve su obra de reforma en Calle Mayor.
  ///
  ///   INDIVIDUAL - Operario: ven solo sus propios partes de trabajo.
  ///                Ej: un operario ve solo lo que el mismo ha registrado.
  ///
  /// VALOR DE RETORNO:
  ///   String con el nivel: 'TOTAL', 'ZONA', 'OBRA' o 'INDIVIDUAL'.
  String get nivelAcceso {
    // Admin y Gestion tienen vision global de la empresa
    if (esAdmin || esGestion) return 'TOTAL';
    // Jefe de obra ve solo su zona geografica o conjunto asignado
    if (esJefeObra) return 'ZONA';
    // Encargado ve solo las obras que supervisa directamente
    if (esEncargado) return 'OBRA';
    // Operario ve solo sus propios registros individuales
    return 'INDIVIDUAL';
  }
}

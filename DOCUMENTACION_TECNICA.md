# Documentación Técnica — Gestión de Partes

**Versión:** 1.0.17+2  
**Repositorio:** https://github.com/riu22/partes_front 
**Stack:** Flutter + Dart + Riverpod + GoRouter + Supabase Auth + REST API

---

## 1. Arquitectura General

La aplicación sigue una **arquitectura de 3 capas** sobre Flutter, con un patrón **offline-first**:

```
┌─────────────────────────────────────────┐
│           Capa de Presentación          │
│   Screens + Widgets (Flutter Widgets)   │
├─────────────────────────────────────────┤
│         Capa de Estado / Lógica         │
│   Providers (Riverpod AsyncNotifier)    │
├─────────────────────────────────────────┤
│           Capa de Datos / Servicios     │
│  ApiService + AuthService + OfflineQueue│
├─────────────────────────────────────────┤
│              Backend (REST API)         │
│       Spring Boot + Supabase Auth       │
└─────────────────────────────────────────┘
```

### Principios

- **Offline-first**: la app funciona sin conexión; los datos se sincronizan automáticamente al recuperar conectividad.
- **RBAC (Role-Based Access Control)**: 5 roles con jerarquía estricta y permisos derivados.
- **Cache local**: los datos críticos (obras, partes, perfil) se cachean en `SharedPreferences`.
- **Cola offline**: los partes creados sin conexión se encolan y sincronizan en orden (normales → jefe → ediciones).
- **Sincronización reactiva**: se activa al recuperar red, al iniciar la app y al volver de segundo plano (`AppLifecycleListener`).

---

## 2. Estructura del Proyecto

```
lib/
├── main.dart                          # Punto de entrada + banner offline
├── config/
│   ├── env.dart                       # Variables de entorno (URLs con defaults)
│   └── router.dart                    # Definición de rutas GoRouter + lazy loading
├── core/
│   └── app_shell.dart                 # Scaffold principal (AppBar + Drawer + 5 tabs)
├── helpers/
│   ├── capture_helper.dart            # Interfaz de captura (screenshots/PDF) — platform dispatcher
│   ├── capture_helper_mobile.dart     # Implementación móvil (stub)
│   ├── capture_helper_web.dart        # Implementación web
│   ├── download_helper.dart           # Interfaz de descarga — platform dispatcher
│   ├── download_helper_desktop.dart   # Implementación escritorio (FilePicker)
│   ├── download_helper_stub.dart      # Stub multiplataforma
│   ├── download_helper_web.dart       # Implementación web (Blob URL)
│   ├── fecha_helpers.dart             # Formateo de fechas (dmy, ymd)
│   ├── perfil_helpers.dart            # Ordenación de perfiles por apellido
│   ├── splash_helper.dart             # Platform dispatcher para ocultar splash
│   ├── splash_helper_web.dart         # Implementación web de splash
│   ├── splash_helper_stub.dart        # Stub de splash
│   ├── tema_constants.dart            # Paleta de colores (Material 3)
│   ├── url_helper.dart                # Platform dispatcher para URLs
│   └── url_helper_web.dart            # Implementación web de URL parsing
├── models/
│   ├── ausencia_info.dart             # Modelo de incidencias de asistencia
│   ├── contabilidad_detalle.dart      # Desglose horario por obra/trabajador
│   ├── obra.dart                      # Modelo de obra
│   ├── parte_trabajo.dart             # Modelo de parte de trabajo
│   ├── pdf_export_params.dart         # Parámetros de exportación PDF/ZIP
│   └── perfil.dart                    # Modelo de perfil de usuario con permisos
├── providers/
│   ├── admin_provider.dart            # Estado de administración (usuarios, ausencias, obras)
│   ├── auth_provider.dart             # Autenticación + servicios
│   ├── connectivity_provider.dart     # Conectividad + sync engine (deprecated en favor de sync_provider)
│   ├── obras_provider.dart            # Obras con caché local + asignaciones
│   ├── partes_provider.dart           # Partes de trabajo + búsqueda + resúmenes
│   ├── perfiles_provider.dart         # Lista de perfiles
│   └── sync_provider.dart             # Motor de sincronización offline (reactivo + lifecycle)
├── screens/
│   ├── login_screen.dart              # Pantalla de inicio de sesión + recuperación password + descarga APK
│   ├── configurarion_screen.dart      # Configuración de perfil
│   ├── NuevaPasswordScreen.dart       # Cambio de contraseña con token
│   ├── admin/
│   │   ├── admin_entry.dart           # Entry point lazy loading (deferred)
│   │   ├── admin_home_screen.dart     # Dashboard de incidencias (ausencias)
│   │   ├── usuarios_screen.dart       # CRUD de usuarios
│   │   ├── crear_usuarios_screen.dart
│   │   ├── editar_usuarios_screen.dart
│   │   ├── asignar_jefe_screen.dart   # Asignación de equipos/jefe
│   │   ├── quincena_screen.dart       # Exportación quincenal (ContabilidadScreen)
│   │   ├── dias_quincena_screen.dart  # Detalle quincenal
│   │   └── fecha_libre_screen.dart    # Gestión de fechas editables
│   ├── obras/
│   │   └── obras_screen.dart          # CRUD de obras + asignación de operarios
│   ├── partes/
│   │   ├── partes_screen.dart         # Listado principal (vistas: lista/semanal/mensual)
│   │   ├── crear_parte_screen.dart    # Despachador de formularios según rol
│   │   ├── formulario_parte_normal.dart
│   │   ├── formulario_parte_jefe.dart
│   │   ├── formulario_parte_postventa.dart
│   │   ├── editar_partes_screen.dart
│   │   ├── editar_partes_jefe_screen.dart
│   │   ├── informe_jefe_screen.dart   # Informe de dedicación por rango
│   │   └── resumen_mensual_jefe_screen.dart
│   ├── pdf/
│   │   ├── pdf_screen.dart            # Exportación PDF/ZIP/zipOperario
│   │   └── report_entry.dart          # Entry point lazy loading (deferred)
│   └── configurarion_screen.dart
├── services/
│   ├── api_service.dart               # Cliente HTTP central (Dio) con interceptors
│   ├── auth_service.dart              # Servicio de autenticación Supabase
│   ├── offline_queue_service.dart     # Cola offline (SharedPreferences con UUID)
│   └── update_service.dart            # Actualización de versión + descarga APK
└── widgets/
    ├── app_drawer.dart
    ├── boton_especialidad.dart
    ├── buscador_obras.dart
    ├── buscador_obras_modal.dart
    ├── buscador_operario.dart
    ├── buscador_operarios_modal.dart
    ├── card_parte.dart
    ├── card_parte_jefe.dart
    ├── chip_especialidad.dart
    ├── day_header.dart
    ├── export_preview.dart
    ├── fecha_tile.dart
    ├── fila_operario.dart
    ├── grupo_operarios.dart
    ├── lazy_screen.dart               # Widget genérico para deferred loading
    ├── lista_cards.dart
    ├── lista_partes.dart
    ├── modo_tile.dart
    ├── obras_selector.dart
    ├── partes_views.dart
    ├── perfiles_selector.dart
    ├── resumen_semanal.dart
    ├── search_field.dart
    ├── seccion_firma.dart
    └── stat_box.dart
```

### Lazy Loading

Las pantallas de administración (`admin/`) y reportes (`pdf/`) se cargan de forma diferida (*deferred*) mediante `lazy_screen.dart` y los entry points `admin_entry.dart` y `report_entry.dart`. Esto reduce el tamaño inicial del bundle.

---

## 3. Modelo de Datos

### 3.1 Perfiles y Roles

```dart
enum Rol {
  ADMINISTRACION,  // Acceso TOTAL
  GESTION,         // Acceso ZONA
  JEFE_DE_OBRA,    // Acceso OBRA
  ENCARGADO,       // Acceso INDIVIDUAL
  OPERARIO         // Acceso INDIVIDUAL
}
```

```dart
class Perfil {
  final String id;
  final String email;
  final String nombre;
  final String apellidos;
  final String rol;
  final bool activo;
  final bool postventa;        // ¿Puede hacer partes de postventa?
  final String especialidad;   // ELECTRICIDAD | FONTANERIA
  final String codigo;         // Código de empleado
  final String grupoProfesional;
}
```

**Propiedades derivadas:**
- `nombreCompleto` — `"$nombre $apellidos"`
- `nombreApellidoCompleto` — `"$apellidos, $nombre"`

**Permisos derivados del rol:**

| Permiso | ADMIN | GESTION | JEFE_OBRA | ENCARGADO | OPERARIO |
|---|---|---|---|---|---|
| `puedeVerEquipos` | ✓ | ✓ | ✓ | ✓ | ✗ |
| `puedeValidar` | ✓ | ✓ | ✓ | ✓ | ✗ |
| `puedeCrearParte` | ✗ | ✗ | ✗ | ✓ | ✓ |
| `puedeEliminar` | ✓ | ✗ | ✗ | ✗ | ✗ |
| `puedeGestionarUsuarios` | ✓ | ✗ | ✗ | ✗ | ✗ |

**Niveles de acceso a datos (`nivelAcceso`):**
- **TOTAL** (ADMINISTRACION, GESTION): todos los datos
- **ZONA** (JEFE_DE_OBRA): datos de sus obras asignadas
- **OBRA** (ENCARGADO): datos de sus obras
- **INDIVIDUAL** (OPERARIO): solo sus propios partes

### 3.2 Obra

```dart
class Obra {
  final int id;
  final String nombre;
  final String ubicacion;
  final String municipio;
  final String poblacion;
  final String codigo;
  final bool activa;
}
```

### 3.3 Parte de Trabajo

```dart
class ParteTrabajo {
  final int id;
  final int? obraId;
  final String obraNombre;
  final String operarioNombre;
  final String operarioApellidos;
  final DateTime fecha;
  final double horasNormales;
  final String descripcion;
  final String? especialidad;     // ELECTRICIDAD | FONTANERIA | null
  final String? operarioId;
  final bool creadoPorGestor;     // Flag si lo creó un ADMIN/GESTION
  final String? firmaUrl;         // URL de la firma digital
  final String? nombreFirma;      // Nombre firmado
  final bool esPostVenta;
  final String trabajosExtra;     // Descripción de trabajos adicionales
}
```

**Propiedades derivadas:**
- `operarioNombreCompleto` — `"$apellidos, $nombre"`
- `puedeEditarse` — solo si la fecha coincide con hoy
- `puedeEditarseConFechas(List<DateTime>)` — permite edición en fechas habilitadas por admin

### 3.4 Parámetros de Exportación PDF

```dart
enum ModoExport { zip, pdf, zipOperario }

class PdfParams {
  final DateTime desde;
  final DateTime hasta;
  final List<int> obraIds;
  final List<String> perfilIds;
  final ModoExport modo;
}
```

### 3.5 Modelos de Asistencia

```dart
enum AusenciaTipo { BAJA, VACACIONES, PATERNIDAD }

class AusenciaLaboral {
  final int? id;
  final String tipo;
  final String fechaInicio;
  final String fechaFin;
  final String? observaciones;
}

class DiaIncompleto {
  final String fecha;
  final String horas;
}

class AusenciaInfo {
  final String perfilId;
  final String nombre;
  final List<String> diasSin;              // Días sin parte (ausencias injustificadas)
  final List<DiaIncompleto> diasIncompletos; // Días con < 8h
  final List<AusenciaLaboral> ausenciasActivas; // Bajas/vacaciones activas
  final int totalLaborables;
  final Set<String> fechasHabilitadas;     // Fechas donde admin permitió editar
}
```

### 3.6 Contabilidad

```dart
class ContabilidadDetalle {
  final String codigo;
  final String operario;
  final String grupoProfesional;
  final String obra;
  final Map<DateTime, double> horasPorDia;
  final double totalHoras;
}
```

---

## 4. Enrutamiento (GoRouter)

Se usa `StatefulShellRoute.indexedStack` para preservar el estado de las 5 pestañas de navegación inferior.

### Rutas en Shell (con navegación inferior)

| Ruta | Pantalla | Roles permitidos |
|---|---|---|
| `/admin` | Dashboard incidencias | ADMINISTRACION, GESTION |
| `/partes` | Listado de partes | Todos autenticados |
| `/partes/nuevo` | Nuevo parte | Todos autenticados (formulario según rol) |
| `/partes/editar` | Editar parte normal | OPERARIO + (solo si puedeEditarse) |
| `/partes/:id` | Vista detalle de parte | Todos autenticados |
| `/obras` | Gestión de obras | ADMINISTRACION, GESTION |
| `/usuarios` | CRUD usuarios | ADMINISTRACION, GESTION |
| `/quincena` | Exportación quincenal | ADMINISTRACION, GESTION |

### Rutas flotantes (fuera del shell)

| Ruta | Pantalla | Roles permitidos |
|---|---|---|
| `/login` | Inicio de sesión | Público |
| `/nueva-password` | Cambio de contraseña con token | Público |
| `/configuracion` | Ajustes de perfil | Todos autenticados |
| `/partes/editar-jefe/:id` | Editar parte jefe | ADMIN, GESTION, JEFE_DE_OBRA |
| `/usuarios/nuevo` | Crear usuario | ADMINISTRACION |
| `/usuarios/editar` | Editar usuario | ADMINISTRACION |
| `/usuarios/asignar-jefe` | Asignar jefe/equipo | ADMINISTRACION |
| `/contabilidad-detalle` | Detalle contable | ADMIN, GESTION, JEFE_DE_OBRA |
| `/fecha-libre` | Gestión fechas editables | ADMINISTRACION, GESTION |
| `/pdf-screen` | Exportación PDF/ZIP | ADMIN, GESTION, JEFE_DE_OBRA |
| `/partes-jefe/informe` | Informe dedicación | ADMIN, GESTION, JEFE_DE_OBRA |
| `/partes-jefe/resumen` | Resumen mensual | ADMIN, GESTION, JEFE_DE_OBRA |

### Protección de rutas

El `redirect` de GoRouter verifica:
1. Estado de autenticación (si no hay sesión → `/login`)
2. Si está autenticado y va a `/login` → redirige a `/admin` (admin/gestion) o `/partes` (resto)
3. Rol del usuario vs. permisos requeridos de la ruta (rutas administrativas redirigen a `/partes`)
4. La ruta `/nueva-password` tiene prioridad absoluta (salta cualquier otra comprobación)

---

## 5. Gestión de Estado (Riverpod)

| Provider | Tipo | Propósito |
|---|---|---|
| `authProvider` | `AsyncNotifierProvider<Perfil?>` | Estado de autenticación |
| `obrasProvider` | `FutureProvider<List<Obra>>` | Lista de obras (con keepAlive + caché local) |
| `obrasActivasProvider` | `FutureProvider<List<Obra>>` | Solo obras activas |
| `misAsignacionesProvider` | `FutureProvider<List<dynamic>>` | Obras asignadas al usuario actual |
| `partesProvider` | `FutureProvider<List<ParteTrabajo>>` | Todos los partes (con caché local) |
| `partesJefeProvider` | `FutureProvider<List<dynamic>>` | Partes de jefe |
| `busquedaPartesProvider` | `FutureProvider.family<List<dynamic>, Map>` | Búsqueda con filtros (obra, operario, especialidad) |
| `fechasPermitidasProvider` | `FutureProvider<List<DateTime>>` | Fechas donde puede editar |
| `resumenMensualJefeProvider` | `FutureProvider.family<Map, ({int anio, int mes})>` | Resumen mensual para jefe |
| `resumenMensualPorUsuarioProvider` | `FutureProvider.family<List, ({int anio, int mes})>` | Resumen mensual por usuario |
| `perfilesProvider` | `FutureProvider<List<Perfil>>` | Todos los perfiles |
| `conectividadProvider` | `StreamProvider<bool>` | Estado de red en tiempo real |
| `pendientesOfflineProvider` | `FutureProvider<int>` | Número de operaciones pendientes en cola |
| `listaOfflineProvider` | `FutureProvider<List<Map>>` | Items de la cola offline para UI |
| `estaSincronizandoProvider` | `StateProvider<bool>` | Flag de sincronización en curso |
| `syncErrorProvider` | `StateProvider<String?>` | Último error de sincronización |
| `syncProvider` | `Provider` | Motor de sincronización reactivo |
| `adminUsuariosProvider` | `FutureProvider<List>` | Usuarios para admin |
| `diasSinParteProvider` | `FutureProvider.autoDispose<Map<String, AusenciaInfo>>` | Dashboard de incidencias |
| `usuariosProvider` | `FutureProvider<List>` | CRUD usuarios |
| `asignacionesObraProvider` | `FutureProvider.family<List, int>` | Operarios asignados a una obra |
| `misObrasProvider` | `FutureProvider<List<Obra>>` | Obras del usuario actual |
| `authServiceProvider` | `Provider<AuthService>` | Instancia del servicio de auth |
| `apiServiceProvider` | `Provider<ApiService>` | Instancia del API service |
| `offlineQueueProvider` | `Provider<OfflineQueueService>` | Instancia de la cola offline |

### Patrones usados

- **`ref.invalidate()`** para invalidar caché tras mutaciones (crear/editar/eliminar).
- **`ref.keepAlive()`** en `obrasProvider` y `obrasActivasProvider` para mantener datos en memoria.
- **`ref.watch()`** en widgets para reactividad.
- **`AsyncValue`** para manejar estados loading/error/data.
- **Deferred loading** con `LazyWidget` para reducir tamaño del bundle inicial.
- **`ref.listen()`** en `syncProvider` para reaccionar a cambios de conectividad.

---

## 6. Servicios

### 6.1 ApiService (`api_service.dart`)

Cliente HTTP central basado en **Dio** (745 líneas). Implementa:

- **Interceptor de refresh**: captura errores 401 y renueva el token automáticamente (con flag `_refrescando` para evitar loops).
- **Timeouts**: 15s para connect, receive y send.

**Endpoints de Usuario:**
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/user/me` | Perfil del usuario autenticado |
| `GET` | `/user/all` | Listar todos los usuarios |
| `POST` | `/user/create_user` | Crear usuario |
| `PUT` | `/user/update_user/:id` | Actualizar usuario |
| `DELETE` | `/user/delete_user/:id` | Eliminar usuario |

**Endpoints de Obras:**
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/obra` | Listar obras |
| `GET` | `/obra/activas` | Obras activas |
| `POST` | `/obra` | Crear obra |
| `PUT` | `/obra/update_obra/:id` | Actualizar obra |
| `DELETE` | `/obra/delete/:id` | Eliminar obra |

**Endpoints de Asignaciones:**
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/asignaciones/:id/subordinados` | Subordinados de un jefe |
| `PUT` | `/asignaciones/asignar_subordinado/:uid/:jefeId` | Asignar subordinado a jefe |
| `DELETE` | `/asignaciones/quitar_subordinado/:uid` | Quitar subordinado |
| `GET` | `/asignaciones/obra/:obraId` | Asignaciones de una obra |
| `POST` | `/asignaciones/asignar_a_obra/:perfilId/:obraId` | Asignar perfil a obra |
| `DELETE` | `/asignaciones/eliminar/:asignacionId` | Eliminar asignación |
| `GET` | `/asignaciones/mis_obras` | Obras del usuario actual |
| `GET` | `/asignaciones/perfil/:perfilId` | Obras de un perfil específico |
| `PUT` | `/asignaciones/asignar_subordinados_batch/:jefeId` | Asignar múltiples subordinados |
| `POST` | `/asignaciones/asignar_obras_batch/:perfilId` | Asignar múltiples obras a un perfil |

**Endpoints de Partes:**
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/partes/get_partes` | Obtener partes |
| `GET` | `/partes/get_partes_jefe` | Partes de jefe |
| `GET` | `/partes/buscar` | Buscar partes con filtros |
| `GET` | `/partes/:id` | Obtener parte por ID |
| `POST` | `/partes/new_parte` | Nuevo parte normal |
| `POST` | `/partes/new_parte_jefe` | Nuevo parte jefe |
| `PUT` | `/partes/update/:id` | Editar parte normal |
| `PUT` | `/partes/update_parte_jefe/:id` | Editar parte jefe |
| `DELETE` | `/partes/delete/:id` | Eliminar parte normal |
| `DELETE` | `/partes/delete_jefe/:id` | Eliminar parte jefe |
| `GET` | `/partes/resumen-mensual-jefe` | Resumen mensual jefe |
| `GET` | `/partes/resumen-mensual-por-usuario` | Resumen por usuario |
| `GET` | `/partes/informe-jefe-rango` | Informe jefe por rango de fechas |
| `GET` | `/partes/mis-fechas-con-parte` | Fechas con parte del usuario actual |
| `GET` | `/partes/fechas-con-parte/:id` | Fechas con parte de un usuario |

**Endpoints de Fechas Libres:**
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/config/fecha-libre` | Obtener fechas libres de todos |
| `GET` | `/config/fecha-libre/mis-fechas` | Fechas libres del usuario actual |
| `POST` | `/config/fecha-libre/habilitar/:id` | Habilitar fechas para un usuario |
| `DELETE` | `/config/fecha-libre/deshabilitar/:id/:fecha` | Deshabilitar una fecha |
| `DELETE` | `/config/fecha-libre/deshabilitar/:id` | Deshabilitar todas las fechas de un usuario |

**Endpoints de Quincena / Contabilidad:**
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/quincena` | Datos quincenales |
| `GET` | `/quincena/exportar` | Exportar XLSX quincenal |
| `GET` | `/quincena/contabilidad-detalle-json` | Detalle contable JSON |
| `GET` | `/quincena/exportar-detalle-csv` | Exportar detalle CSV/XLSX |
| `GET` | `/quincena/jefe/contabilidad-detalle-json` | Detalle contable para jefe |
| `GET` | `/quincena/jefe/exportar-detalle-csv` | Exportar detalle para jefe |

**Endpoints de Ausencias:**
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/ausencias/dias-sin-parte` | Días sin parte (dashboard incidencias) |
| `POST` | `/ausencias/laborales` | Registrar ausencia laboral |
| `DELETE` | `/ausencias/laborales/:id` | Eliminar ausencia laboral |
| `GET` | `/ausencias/laborales/perfil/:perfilId` | Ausencias de un perfil |

**Endpoints de Exportación PDF:**
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/pdf/partes` | Generar PDF de partes |
| `GET` | `/pdf/partes-zip` | Generar ZIP con PDFs |
| `GET` | `/pdf/zip-por-operario` | ZIP agrupado por operario |

**Otros:**
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/version` | Versión actual de la app |

### 6.2 AuthService (`auth_service.dart`)

Integración con **Supabase Auth**:

- Login con email/contraseña (password grant) contra `${SUPABASE_URL}/auth/v1/token?grant_type=password`
- Persistencia local del JWT + refresh token en `flutter_secure_storage`
- Verificación de expiración del JWT (decodifica payload, compara `exp`)
- Refresco automático de tokens (`refresh_token` grant)
- Cambio de contraseña (`PUT /auth/v1/user`)
- Cambio de contraseña con token de recuperación
- Recuperación de contraseña (`POST /auth/v1/recover` con `redirect_to`)
- Verificación de token de recuperación desde URL (parsing de fragmentos `#`)
- Modo offline: respuesta desde el perfil cacheado en secure storage
- Caché en memoria del token (`_tokenCache`)

### 6.3 OfflineQueueService (`offline_queue_service.dart`)

Cola de operaciones pendientes usando `SharedPreferences`:

- Tres colas separadas: partes normales, partes jefe, actualizaciones (ediciones)
- Inserción con metadatos: `queue_id` (UUID v4), `timestamp`, `data`
- Borrado atómico por `queue_id` (evita problemas de índices)
- Sincronización automática al recuperar conectividad
- `prefs.reload()` antes de cada operación para evitar race conditions

### 6.4 UpdateService (`update_service.dart`)

- Consulta `GET /version` para comparar con la versión local (`package_info_plus`)
- Lanza URL de descarga de APK si hay una versión más reciente
- Botón de descarga en login screen (solo web, `kIsWeb`)

---

## 7. Sincronización Offline

El flujo de sincronización se activa mediante 3 disparadores en `sync_provider.dart`:

```
1. CAMBIO DE RED: connectivityProvider pasa de false a true
2. COLD START: Al abrir la app desde cero (Future.microtask)
3. CICLO DE VIDA: Al volver de segundo plano (AppLifecycleListener.onResume)

[Offline] Usuario crea parte
       ↓
Se guarda en SharedPreferences (cola offline con UUID)
       ↓
[Disparador de sincronización]
       ↓
syncProvider._sincronizar()
       ↓
1. Verificar/refrescar JWT
2. Procesar cola de partes normales (con manejo de errores 4xx/5xx)
3. Procesar cola de partes de jefe
4. Procesar cola de actualizaciones (ediciones)
5. Invalidar providers para refrescar UI
```

### Manejo de errores

- **Errores 4xx descartables** (400, 404, 422, etc.): el elemento se descarta y se continúa con el siguiente
- **Errores 5xx**: se salta el elemento para no bloquear la cola (efecto tapón)
- **Errores 401**: se intenta refrescar el token; si falla, se fuerza logout
- **Errores de red**: se detiene la sincronización (se reintentará en el próximo disparador)
- Estados reactivos: `estaSincronizandoProvider` y `syncErrorProvider` para UI

### Orden de sincronización

1. Partes normales
2. Partes de jefe
3. Actualizaciones/ediciones

Cada cola se procesa secuencialmente con `List.from()` para evitar mutaciones durante la iteración.

---

## 8. Tipos de Parte de Trabajo

### 8.1 Parte Normal
- Registro de un día completo
- Una sola obra
- Horas trabajadas (normales)
- Especialidad (ELECTRICIDAD / FONTANERIA)
- Firma digital (URL + nombre firmado)
- Descripción de tareas + trabajos extra
- Validación (creadoPorGestor flag)
- Postventa flag

### 8.2 Parte de Jefe
- Distribución porcentual de horas entre múltiples obras
- Rango de fechas (varios días)
- Operarios asignados a su equipo
- Cálculo automático de horas por obra según porcentaje

### 8.3 Parte de Postventa
- Trabajos de servicio técnico/postventa
- Asignación de operarios específicos
- Seguimiento independiente

---

## 9. Exportación

### PDF (generado del lado del servidor)
- Individual: un PDF por trabajador
- Agrupado: todos los trabajadores en un mismo PDF
- Los PDFs se generan mediante `GET /pdf/partes`

### ZIP
- ZIP general con todos los PDFs (`GET /pdf/partes-zip`)
- ZIP por operario: agrupado por trabajador (`GET /pdf/zip-por-operario`)

### Quincena (XLSX + CSV)
- Exportación de datos horarios quincenales (`/quincena/exportar`)
- Desglose contable por trabajador y obra (`/quincena/contabilidad-detalle-json`)
- Exportación CSV detallado (`/quincena/exportar-detalle-csv`)
- Vista específica para jefe de obra (`/quincena/jefe/*`)
- Vista previa antes de descargar

---

## 10. Roles y Permisos

| Permiso | ADMIN | GESTION | JEFE_OBRA | ENCARGADO | OPERARIO |
|---|---|---|---|---|---|
| Ver equipos | ✓ | ✓ | ✓ | ✓ | ✗ |
| Validar partes | ✓ | ✓ | ✓ | ✓ | ✗ |
| Crear partes | ✗ | ✗ | ✗ | ✓ | ✓ |
| Editar partes | ✓ (fecha actual) | ✓ (fecha actual) | ✓ | ✓ | ✓ (solo propias, fecha actual) |
| Eliminar partes | ✓ | ✗ | ✗ | ✗ | ✗ |
| Gestionar obras | ✓ | ✓ | ✗ | ✗ | ✗ |
| Gestionar usuarios | ✓ | ✗ | ✗ | ✗ | ✗ |
| Exportar PDF | ✓ | ✓ | ✓ | ✗ | ✗ |
| Acceso admin dashboard | ✓ | ✓ | ✗ | ✗ | ✗ |
| Fechas editables | ✓ | ✓ | ✗ | ✗ | ✗ |

Nota: la edición de partes está restringida al día actual (`puedeEditarse`), excepto cuando un administrador habilita fechas concretas (`puedeEditarseConFechas`).

---

## 11. Plataformas Soportadas

| Plataforma | Estado | Build |
|---|---|---|
| Android | ✅ Producción | `flutter build apk --release --target-platform android-arm,android-arm64` |
| Web | ✅ Producción | `flutter build web --release --dart-define=FLUTTER_WEB_RENDERER=html` |
| iOS | ⚠️ Configurado (no probado) | `flutter build ios` |
| Linux | ⚠️ Configurado (no probado) | `flutter build linux` |
| macOS | ⚠️ Configurado (no probado) | `flutter build macos` |
| Windows | ⚠️ Configurado (no probado) | `flutter build windows` |

### Diferencias por plataforma

- **Captura de pantalla**: platform dispatcher vía exports condicionales (`dart.library.html` → web, resto → mobile stub)
- **Descarga de archivos**: web usa Blob URL, escritorio usa FilePicker (`saveAndLaunchFile`), stub para no soportadas
- **Actualización**: comprobación de versión solo fuera de web (`!kIsWeb`); botón de descarga APK solo visible en web (`kIsWeb`)
- **Notificaciones**: banner de conexión en todas las plataformas (`_NoConnectionBanner`)
- **Splash screen**: implementación específica para web (`splash_helper_web.dart`)
- **URL parsing**: implementación específica para web (`url_helper_web.dart`) para extraer tokens de recuperación

---

## 12. Configuración del Entorno

Variables definidas en `.env` (cargadas vía `flutter_dotenv`). El sistema tiene valores por defecto que cambian según el modo (debug/release):

| Variable | Propósito | Default (debug) | Default (release) |
|---|---|---|---|
| `SUPABASE_URL` | URL del servidor Supabase | `http://192.168.110.129:8000` | `http://192.168.110.190:8000` |
| `SUPABASE_ANON_KEY` | Clave anónima de Supabase | (default demo key) | (default demo key) |
| `API_URL` | URL base de la API REST | `http://192.168.110.129:8081/api/v1` | `http://192.168.110.190:8081/api/v1` |
| `APP_URL` | URL de la app web | `http://192.168.110.129:3000` | `http://192.168.110.190:3000` |
| `APK_URL` | URL de descarga del APK | `http://192.168.110.190:8000/storage/v1/object/public/instaladores/app-release.apk` | misma |

La lógica de defaults usa `kReleaseMode` para elegir IP: `192.168.110.129` (debug/local) vs `192.168.110.190` (release/servidor).

---

## 13. CI/CD

**GitHub Actions** (`.github/workflows/deploy.yml`) — se ejecuta en push a `main`:

```
1. Checkout + Setup Java 17 (Zulu) + Flutter stable (subosito/flutter-action)
2. Crear .env desde GitHub Secrets (SUPABASE_URL, SUPABASE_ANON_KEY, API_URL, APP_URL, APK_URL)
3. Restaurar Android keystore (Base64 → android/app/release.jks)
4. Crear key.properties desde secrets
5. flutter pub get
6. flutter build apk --release --target-platform android-arm,android-arm64
7. flutter build web --release --dart-define=FLUTTER_WEB_RENDERER=html --dart-define-from-file=.env
8. Subir APK a Supabase Storage (OTA updates, vía curl)
9. Subir APK a GitHub Artifacts (retención 7 días)
10. Docker login + build + push a Docker Hub
```

### Despliegue Web
- **Vercel**: SPA con rewrites configurados en `vercel.json` (no automatizado en CI actual)
- **Docker**: imagen nginx:alpine sirviendo `build/web`

---

## 14. Dependencias Principales

```yaml
flutter_riverpod: ^2.6.1    # Estado global
go_router: ^17.2.3          # Enrutamiento
dio: ^5.4.3                 # HTTP client
shared_preferences: ^2.5.5  # Almacenamiento local
flutter_secure_storage: ^10.2.0  # Almacenamiento seguro (JWT + perfil)
connectivity_plus: ^7.1.1   # Monitoreo de red
pdf: ^3.11.0                # Generación de PDF
printing: ^5.13.0           # Impresión
signature: ^6.3.0           # Firma digital
url_launcher: ^6.3.2        # Apertura de URLs
flutter_dotenv: ^6.0.1      # Variables de entorno
share_plus: ^13.1.0         # Compartir archivos
path_provider: ^2.1.0       # Rutas de archivos
package_info_plus: ^10.1.0  # Información del paquete
intl: ^0.20.2               # Internacionalización
uuid: ^4.3.3                # Generación de UUIDs para cola offline
flutter_lints: ^6.0.0       # Linting
flutter_launcher_icons: ^0.14.4  # Iconos de app
```

---

## 15. Convenciones de Código

- **Linting**: `flutter_lints ^6.0.0` (configurado en `analysis_options.yaml`)
- **Idioma**: códigos y comentarios en español
- **Nomenclatura**: `snake_case` para archivos, `camelCase` para variables/funciones, `PascalCase` para clases
- **Arquitectura**: screens en `screens/`, widgets reutilizables en `widgets/`, lógica de negocio en `providers/`, acceso a datos en `services/`, modelos en `models/`
- **Estado**: Riverpod con `AsyncNotifierProvider`, `FutureProvider`, `StreamProvider`, `StateProvider`
- **Persistencia offline**: `SharedPreferences` para caché de datos y cola de operaciones; `flutter_secure_storage` para JWT + refresh token + perfil
- **Caché**: patrón try/catch con fallback a `SharedPreferences`
- **Lazy loading**: pantallas de admin y reportes cargadas con deferred imports via `LazyWidget`
- **Platform dispatch**: exports condicionales para helpers (`dart.library.html`, `dart.library.js`, `dart.library.io`)

---

## 16. Testing

Actualmente solo existe una prueba básica (`test/widget_test.dart`) que es el template por defecto de Flutter y no cubre la funcionalidad real de la aplicación.

```bash
flutter test
```

---

## 17. Seguridad

- **JWT**: almacenado en `flutter_secure_storage` (cifrado a nivel de sistema operativo)
- **Refresh token**: almacenado en `flutter_secure_storage`, renovación automática en AuthService
- **Modo offline**: nunca se almacenan contraseñas en texto plano; solo se cachea el perfil
- **API Key**: la `SUPABASE_ANON_KEY` se carga desde `.env` con un default demo key, no hardcodeada en el código de producción
- **Keystore**: inyectado via GitHub Secrets en CI/CD, no incluido en el repositorio
- **Interceptor 401**: renovación automática de token con flag `_refrescando` para evitar refresh en cascada
- **Expiración JWT**: verificación local decodificando el payload antes de usarlo

## Legal

Este software ha sido desarrollado por Riu (https://github.com/riu22) y su propiedad 
intelectual pertenece al autor. La empresa dispone de una licencia 
limitada de uso. Cualquier modificación realizada sin el consentimiento 
del autor no es responsabilidad del desarrollador original.

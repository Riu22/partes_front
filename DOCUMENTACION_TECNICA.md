# Documentación Técnica — Gestión de Partes

**Versión:** 1.0.13+1  
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

---

## 2. Estructura del Proyecto

```
lib/
├── main.dart                          # Punto de entrada
├── config/
│   ├── env.dart                       # Variables de entorno (URLs)
│   └── router.dart                    # Definición de rutas GoRouter
├── core/
│   └── app_shell.dart                 # Scaffold principal (AppBar + Drawer)
├── helpers/
│   ├── capture_helper.dart            # Interfaz de captura (screenshots/PDF)
│   ├── capture_helper_mobile.dart     # Implementación móvil
│   ├── capture_helper_web.dart        # Implementación web
│   ├── download_helper.dart           # Interfaz de descarga
│   ├── download_helper_desktop.dart   # Implementación escritorio
│   ├── download_helper_stub.dart      # Stub multiplataforma
│   ├── download_helper_web.dart       # Implementación web
│   ├── fecha_helpers.dart             # Formateo de fechas (dmy, ymd)
│   ├── perfil_helpers.dart            # Ordenación de perfiles
│   └── tema_constants.dart            # Paleta de colores (Material 3)
├── models/
│   ├── ausencia_info.dart             # Modelo de incidencias de asistencia
│   ├── contabilidad_detalle.dart      # Desglose horario por obra/trabajador
│   ├── obra.dart                      # Modelo de obra
│   ├── parte_trabajo.dart             # Modelo de parte de trabajo
│   ├── pdf_export_params.dart         # Parámetros de exportación PDF/ZIP
│   └── perfil.dart                    # Modelo de perfil de usuario
├── providers/
│   ├── admin_provider.dart            # Estado de administración
│   ├── auth_provider.dart             # Autenticación + servicios
│   ├── connectivity_provider.dart     # Conectividad + sincronización
│   ├── obras_provider.dart            # Obras con caché local
│   ├── partes_provider.dart           # Partes de trabajo + búsqueda
│   ├── perfiles_provider.dart         # Lista de perfiles
│   └── sync_provider.dart             # Motor de sincronización offline
├── screens/
│   ├── login_screen.dart              # Pantalla de inicio de sesión
│   ├── configurarion_screen.dart      # Configuración de perfil
│   ├── NuevaPasswordScreen.dart       # Cambio de contraseña
│   ├── admin/
│   │   ├── admin_home_screen.dart     # Dashboard de administración
│   │   ├── usuarios_screen.dart       # CRUD de usuarios
│   │   ├── crear_usuarios_screen.dart
│   │   ├── editar_usuarios_screen.dart
│   │   ├── asignar_jefe_screen.dart   # Asignación de equipos
│   │   ├── quincena_screen.dart       # Exportación quincenal
│   │   ├── dias_quincena_screen.dart  # Detalle quincenal
│   │   └── fecha_libre_screen.dart    # Gestión de fechas libres
│   ├── obras/
│   │   └── obras_screen.dart          # CRUD de obras
│   ├── partes/
│   │   ├── partes_screen.dart         # Listado principal
│   │   ├── crear_parte_screen.dart    # Despachador de formularios
│   │   ├── formulario_parte_normal.dart
│   │   ├── formulario_parte_jefe.dart
│   │   ├── formulario_parte_postventa.dart
│   │   ├── editar_partes_screen.dart
│   │   ├── editar_partes_jefe_screen.dart
│   │   ├── informe_jefe_screen.dart   # Informe de dedicación
│   │   └── resumen_mensual_jefe_screen.dart
│   └── pdf/
│       └── pdf_screen.dart            # Exportación PDF/ZIP
├── services/
│   ├── api_service.dart               # Cliente HTTP central (Dio)
│   ├── auth_service.dart              # Servicio de autenticación Supabase
│   ├── offline_queue_service.dart     # Cola offline (SharedPreferences)
│   └── update_service.dart            # Actualización de versión
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

---

## 3. Modelo de Datos

### 3.1 Perfiles y Roles

```
enum Rol {
  ADMINISTRACION,  // Acceso TOTAL
  GESTION,         // Acceso ZONA
  JEFE_DE_OBRA,    // Acceso OBRA
  ENCARGADO,       // Acceso INDIVIDUAL
  OPERARIO         // Acceso INDIVIDUAL
}
```

Cada rol tiene permisos derivados:
- `puedeVerEquipos` — ADMINISTRACION, GESTION
- `puedeValidar` — ADMINISTRACION, GESTION
- `puedeCrearParte` — todos excepto OPERARIO
- `puedeEliminar` — solo ADMINISTRACION
- `puedeGestionarObras` — ADMINISTRACION, GESTION

### 3.2 Obra

```dart
class Obra {
  final int id;
  final String nombre;
  final String? ubicacion;
  final String? municipio;
  final String? codigo;
  final bool activo;
}
```

### 3.3 Parte de Trabajo

El modelo `ParteTrabajo` representa un registro laboral con:

- `fecha` — fecha del parte
- `horas` — horas trabajadas
- `descripcion` — descripción de la tarea
- `especialidad` — ELECTRICIDAD | FONTANERIA | AMBAS
- `firmaDigital` — cadena base64 de la firma
- `esPostVenta` — flag de postventa
- `esJefe` — distingue parte normal de parte de jefe
- `validado` — estado de validación
- Lista de IDs de operarios asignados

### 3.4 Parámetros de Exportación PDF

```dart
class PdfExportParams {
  final DateTime inicio;
  final DateTime fin;
  final List<int>? obraIds;
  final List<int>? perfilIds;
  final ExportMode modo; // INDIVIDUAL | AGRUPADO |
}
```

---

## 4. Enrutamiento (GoRouter)

| Ruta | Pantalla | Roles permitidos |
|---|---|---|
| `/login` | Inicio de sesión | Público |
| `/nueva-password` | Cambio de contraseña | Público |
| `/partes` | Listado de partes | Todos autenticados |
| `/partes/nuevo` | Nuevo parte | OPERARIO + |
| `/partes/editar` | Editar parte normal | OPERARIO + |
| `/partes/editar-jefe/:id` | Editar parte jefe | JEFE_DE_OBRA + |
| `/obras` | Gestión de obras | ADMINISTRACION, GESTION |
| `/admin` | Panel admin | ADMINISTRACION |
| `/usuarios` | CRUD usuarios | ADMINISTRACION |
| `/quincena` | Exportación quincenal | ADMINISTRACION, GESTION |
| `/fecha-libre` | Gestión fechas editables | ADMINISTRACION |
| `/pdf-screen` | Exportación PDF | ADMINISTRACION, GESTION |
| `/partes-jefe/informe` | Informe dedicación | JEFE_DE_OBRA |
| `/partes-jefe/resumen` | Resumen mensual | JEFE_DE_OBRA |

Las rutas están protegidas mediante el `redirect` de GoRouter que verifica:
1. Estado de autenticación
2. Rol del usuario vs. permisos requeridos de la ruta
3. Aunque se llegue a las rutas por enlace externo se comprueba que el rol pueda acceder a la informacion de la ruta, si no es así se redirige a la pantalla de inicio de sesión

Se usa `StatefulShellRoute.indexedStack` para preservar el estado de las pestañas inferiores durante la navegación.

---

## 5. Gestión de Estado (Riverpod)

| Provider | Tipo | Propósito |
|---|---|---|
| `authProvider` | `AsyncNotifierProvider<Perfil?>` | Estado de autenticación |
| `obrasProvider` | `FutureProvider<List<Obra>>` | Lista de obras (con keepAlive) |
| `obrasActivasProvider` | `FutureProvider<List<Obra>>` | Solo obras activas |
| `partesPorSemanaProvider` | `FutureProvider` | Partes agrupados por semana |
| `partesProvider` | `FutureProvider` | Todos los partes (con caché) |
| `perfilesProvider` | `FutureProvider` | Todos los perfiles |
| `connectivityProvider` | `StreamProvider<bool>` | Estado de red |
| `adminUsuariosProvider` | `FutureProvider` | Usuarios para admin |
| `syncProvider` | `Provider` | Motor de sincronización |

### Patrones usados

- **`ref.invalidate()`** para invalidar caché tras mutaciones (crear/editar/eliminar).
- **`ref.keepAlive()`** en `obrasProvider` para mantener datos en memoria.
- **`ref.watch()`** en widgets para reactividad.
- **`AsyncValue`** para manejar estados loading/error/data.

---

## 6. Servicios

### 6.1 ApiService (`api_service.dart`)

Cliente HTTP central basado en **Dio** (709 líneas). Implementa:

- **Interceptor de autenticación**: adjunta el JWT en cada petición.
- **Interceptor de refresh**: captura errores 401 y renueva el token automáticamente.
- **Endpoints**:
  - `POST /api/v1/auth/profile` — perfil del usuario autenticado
  - `GET /api/v1/usuarios` — listar usuarios
  - `POST /api/v1/usuarios` — crear usuario
  - `PUT /api/v1/usuarios/:id` — actualizar usuario
  - `DELETE /api/v1/usuarios/:id` — eliminar usuario
  - `GET /api/v1/obras` — listar obras
  - `POST /api/v1/obras` — crear obra
  - `PUT /api/v1/obras/:id` — actualizar obra
  - `DELETE /api/v1/obras/:id` — eliminar obra
  - `GET /api/v1/partes` — listar partes (con filtros)
  - `POST /api/v1/partes/nuevo` — crear parte normal
  - `POST /api/v1/partes/jefe/nuevo` — crear parte de jefe
  - `PUT /api/v1/partes/:id` — actualizar parte
  - `DELETE /api/v1/partes/:id` — eliminar parte
  - `POST /api/v1/partes/jefe/repartir` — distribuir horas como jefe
  - `GET /api/v1/contabilidad/detalle` — detalle contable
  - `GET /api/v1/ausencias` — días sin parte
  - `POST /api/v1/ausencias/agregar` — agregar ausencia
  - `GET /api/v1/fechas-libres` — fechas editables
  - `POST /api/v1/fechas-libres` — habilitar/deshabilitar fecha
  - `GET /api/v1/quincena` — datos quincenales
  - `GET /api/v1/quincena/exportar` — exportar XLSX
  - `GET /api/v1/pdf/exportar` — exportar PDF/ZIP
  - `GET /api/v1/version` — versión actual de la app

### 6.2 AuthService (`auth_service.dart`)

Integración con **Supabase Auth**:

- Login con email/contraseña (password grant)
- Persistencia local del JWT en `flutter_secure_storage`
- Verificación de expiración del JWT
- Refresco automático de tokens
- Cambio de contraseña
- Recuperación de contraseña
- Modo offline: respuesta desde el perfil cacheado

### 6.3 OfflineQueueService (`offline_queue_service.dart`)

Cola de operaciones pendientes usando `SharedPreferences`:

- Tres colas separadas: partes normales, partes jefe, actualizaciones
- Inserción FIFO con almacenamiento como JSON strings
- Eliminación individual por coincidencia de contenido (evita problemas de índices)
- Sincronización automática al recuperar conectividad
- Orden de sincronización: 1) partes normales, 2) partes jefe, 3) ediciones

### 6.4 UpdateService (`update_service.dart`)

- Consulta `GET /api/v1/version` para comparar con la versión local
- Lanza URL de descarga de APK si hay una versión más reciente

---

## 7. Sincronización Offline

El flujo de sincronización se activa mediante el `connectivityProvider` cuando la conexión pasa de `false` a `true`:

```
[Offline] Usuario crea parte
       ↓
Se guarda en SharedPreferences (cola offline)
       ↓
[Reconexión] connectivityProvider emite true
       ↓
syncProvider._sincronizar()
       ↓
1. Procesar cola de partes normales
2. Procesar cola de partes de jefe
3. Procesar cola de actualizaciones
4. Invalidar providers para refrescar UI
```

El JWT se verifica antes de sincronizar; si ha expirado, se renueva automáticamente.

---

## 8. Tipos de Parte de Trabajo

### 8.1 Parte Normal
- Registro de un día completo
- Una sola obra
- Horas trabajadas (regulares + extras)
- Especialidad (ELECTRICIDAD / FONTANERIA / AMBAS)
- Firma digital
- Descripción de tareas

### 8.2 Parte de Jefe
- Distribución porcentual de horas entre múltiples obras
- Rango de fechas (varios días)
- Cálculo automático de horas por obra según porcentaje
- Aprobación/validación requerida por ADMINISTRACION

### 8.3 Parte de Postventa
- Trabajos de servicio técnico/postventa
- Asignación de operarios específicos
- Seguimiento independiente

---

## 9. Exportación

### PDF
- Individual: un PDF por trabajador
- Agrupado: todos los trabajadores en un mismo PDF
- Jefe de Obra: resumen por obra con detalle de operarios
- Los PDFs se generan del lado del servidor

### ZIP
- ZIP individual por trabajador conteniendo sus PDFs
- ZIP general con todos los PDFs agrupados

### Quincena (XLSX + CSV)
- Exportación de datos horarios quincenales
- Desglose por trabajador y obra
- Formato XLSX para Excel y CSV para análisis

---

## 10. Roles y Permisos

| Permiso | ADMIN | GESTION | JEFE_OBRA | ENCARGADO | OPERARIO |
|---|---|---|---|---|---|
| Ver equipos | ✓ | ✓ | ✗ | ✗ | ✗ |
| Validar partes | ✓ | ✓ | ✗ | ✗ | ✗ |
| Crear partes | ✓ | ✓ | ✓ | ✓ | ✗ |
| Editar partes | ✓ | ✓ | ✓ | ✓ | ✓ |
| Eliminar partes | ✓ | ✗ | ✗ | ✗ | ✗ |
| Gestionar obras | ✓ | ✓ | ✗ | ✗ | ✗ |
| Gestionar usuarios | ✓ | ✗ | ✗ | ✗ | ✗ |
| Exportar PDF | ✓ | ✓ | ✗ | ✗ | ✗ |
| Acceso admin | ✓ | ✗ | ✗ | ✗ | ✗ |

### Niveles de acceso a datos
- **TOTAL** (ADMINISTRACION): todos los datos
- **ZONA** (GESTION): datos de su zona geográfica
- **OBRA** (JEFE_DE_OBRA): datos de sus obras asignadas
- **INDIVIDUAL** (ENCARGADO, OPERARIO): solo sus propios datos

---

## 11. Plataformas Soportadas

| Plataforma | Estado | Build |
|---|---|---|
| Android | ✅ Producción | `flutter build apk --release` |
| Web | ✅ Producción | `flutter build web --release` |
| iOS | ⚠️ Configurado (no probado) | `flutter build ios` |
| Linux | ⚠️ Configurado (no probado) | `flutter build linux` |
| macOS | ⚠️ Configurado (no probado) | `flutter build macos` |
| Windows | ⚠️ Configurado (no probado) | `flutter build windows` |

### Diferencias por plataforma

- **Captura de pantalla**: implementación nativa en móvil (`capture_helper_mobile.dart`), alternativa web (`capture_helper_web.dart`)
- **Descarga de archivos**: implementación específica para web (Blob URL), escritorio (FilePicker), y stub para no soportadas
- **Actualización**: botón de descarga de APK solo visible en web (`kIsWeb`)
- **Notificaciones**: banner de conexión en todas las plataformas

---

## 12. Configuración del Entorno

Variables definidas en `.env` (cargadas vía `flutter_dotenv`):

| Variable | Propósito | Default (debug) | Default (release) |
|---|---|---|---|
| `SUPABASE_URL` | URL del servidor Supabase | `http://192.168.110.129:8000` | `http://192.168.110.190:8000` |
| `SUPABASE_ANON_KEY` | Clave anónima de Supabase | — | — |
| `API_URL` | URL base de la API REST | `http://192.168.110.129:8081/api/v1` | `http://192.168.110.190:8081/api/v1` |

---

## 13. CI/CD

**GitHub Actions** (`.github/workflows/deploy.yml`) — se ejecuta en push a `main`:

```
1. Checkout + Setup Java 17 (Zulu) + Flutter stable
2. Crear .env desde GitHub Secrets
3. Restaurar Android keystore (Base64)
4. flutter build apk --release
5. flutter build web --release
6. Subir APK a Supabase Storage (OTA updates)
7. Subir APK a GitHub Artifacts (7 días)
8. Docker build + push a Docker Hub
```

### Despliegue Web
- **Vercel**: SPA con rewrites configurados en `vercel.json`
- **Docker**: imagen nginx:alpine sirviendo `build/web`

---

## 14. Dependencias Principales

```yaml
flutter_riverpod: ^2.5.1    # Estado global
go_router: ^13.2.0          # Enrutamiento
dio: ^5.4.3                 # HTTP client
shared_preferences: ^2.2.3  # Almacenamiento local
flutter_secure_storage: ^9.0.0  # Almacenamiento seguro
connectivity_plus: ^7.0.0   # Monitoreo de red
pdf: ^3.11.0                # Generación de PDF
printing: ^5.13.0           # Impresión
signature: ^5.4.0           # Firma digital
url_launcher: ^6.3.2        # Apertura de URLs
flutter_dotenv: ^5.1.0      # Variables de entorno
share_plus: ^10.0.0         # Compartir archivos
path_provider: ^2.1.0       # Rutas de archivos
package_info_plus: ^8.0.0   # Información del paquete
flutter_lints: ^6.0.0       # Linting
flutter_launcher_icons: ^0.14.4  # Iconos de app
```

---

## 15. Convenciones de Código

- **Linting**: `flutter_lints ^6.0.0` (configurado en `analysis_options.yaml`)
- **Idioma**: códigos y comentarios en español
- **Nomenclatura**: `snake_case` para archivos, `camelCase` para variables/funciones, `PascalCase` para clases
- **Arquitectura**: screens en `screens/`, widgets reutilizables en `widgets/`, lógica de negocio en `providers/`, acceso a datos en `services/`, modelos en `models/`
- **Estado**: Riverpod con `AsyncNotifierProvider` y `FutureProvider`
- **Persistencia offline**: `SharedPreferences` para caché de datos y cola de operaciones; `flutter_secure_storage` para JWT

---

## 16. Testing

Actualmente solo existe una prueba básica (`test/widget_test.dart`) que es el template por defecto de Flutter y no cubre la funcionalidad real de la aplicación.

```bash
flutter test
```

---

## 17. Seguridad

- **JWT**: almacenado en `flutter_secure_storage` (cifrado a nivel de sistema operativo)
- **Refresh token**: renovación automática en interceptador de Dio
- **Modo offline**: nunca se almacenan contraseñas en texto plano
- **API Key**: la `SUPABASE_ANON_KEY` se carga desde `.env` y no está hardcodeada
- **Keystore**: inyectado via GitHub Secrets en CI/CD, no incluido en el repositorio

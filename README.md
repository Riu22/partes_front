# Gestión de Partes

Aplicación multiplataforma (Android, iOS, Web, Windows, macOS, Linux) para la gestión de **partes de trabajo** (registro de horas laborales) en el sector de la construcción/instalaciones. Desarrollada con Flutter.

---

## Stack Tecnológico

| Componente | Tecnología |
|---|---|
| **Frontend** | Flutter 3.x (Dart) |
| **Estado** | Riverpod (`flutter_riverpod`) |
| **Ruteo** | GoRouter (`go_router`) |
| **HTTP** | Dio (`dio`) |
| **Auth** | Supabase Auth |
| **Backend** | API REST propia (Java / Springboot) |
| **Almacén local** | `shared_preferences` + `flutter_secure_storage` |
| **PDF** | `pdf` + `printing` (generación server-side) |
| **Offline** | Cola offline con `connectivity_plus` + `uuid` |
| **CI/CD** | GitHub Actions → Docker Hub + Supabase Storage |

---

## Roles y Permisos

| Rol | Acceso a Datos | Crea Partes | Valida | Gestiona Usuarios | Exporta PDF |
|---|---|---|---|---|---|
| `ADMINISTRACION` | TOTAL | No (crea para otros) | Sí | Sí | Sí |
| `GESTION` | TOTAL | No (crea para otros) | Sí | Sí | Sí |
| `JEFE_DE_OBRA` | ZONA (sus obras) | No (parte jefe %) | Sí | No | Sí (su zona) |
| `ENCARGADO` | OBRA (su obra) | Sí | Sí | No | No |
| `OPERARIO` | INDIVIDUAL (propio) | Sí | No | No | No |

Nota: solo `OPERARIO` y `ENCARGADO` pueden crear partes de trabajo (`puedeCrearParte`). La edición está restringida al día actual, salvo fechas habilitadas por administración.

---

## Arquitectura

```
lib/
├── main.dart                  # Entry point + banner offline
├── config/
│   ├── env.dart               # Config desde .env (URLs con defaults)
│   └── router.dart            # Definición de rutas go_router + lazy loading
├── core/
│   └── app_shell.dart         # Scaffold principal (AppBar + Drawer + 5 tabs)
├── helpers/
│   ├── capture_helper.*       # Captura de pantalla/PDF (platform dispatcher)
│   ├── download_helper.*      # Descarga de archivos (platform dispatcher)
│   ├── fecha_helpers.dart     # Formateo de fechas
│   ├── perfil_helpers.dart    # Ordenación de perfiles
│   ├── splash_helper.*       # Ocultar splash screen (platform)
│   ├── tema_constants.dart    # Colores del tema
│   └── url_helper.*          # URL parsing (platform dispatcher)
├── models/
│   ├── ausencia_info.dart     # Incidencias de asistencia
│   ├── contabilidad_detalle.dart # Desglose de horas
│   ├── obra.dart              # Obra (worksite)
│   ├── parte_trabajo.dart     # Parte de trabajo
│   ├── pdf_export_params.dart # Parámetros de exportación (PdfParams)
│   └── perfil.dart            # Perfil de usuario con permisos
├── providers/
│   ├── admin_provider.dart    # Estado admin (usuarios, asignaciones, ausencias)
│   ├── auth_provider.dart     # Autenticación (login/logout/offline)
│   ├── connectivity_provider.dart # Conectividad (deprecated)
│   ├── obras_provider.dart    # Obras con caché local + asignaciones
│   ├── partes_provider.dart   # Partes, búsqueda, resúmenes
│   ├── perfiles_provider.dart # Perfiles de usuario
│   └── sync_provider.dart     # Sincronización offline→online (reactiva + lifecycle)
├── screens/
│   ├── login_screen.dart      # Login con offline + descarga APK
│   ├── configurarion_screen.dart # Ajustes de perfil
│   ├── NuevaPasswordScreen.dart  # Restablecer contraseña con token
│   ├── admin/
│   │   ├── admin_entry.dart         # Entry point deferred
│   │   ├── admin_home_screen.dart   # Dashboard incidencias
│   │   ├── usuarios_screen.dart     # CRUD usuarios
│   │   ├── crear_usuarios_screen.dart
│   │   ├── editar_usuarios_screen.dart
│   │   ├── asignar_jefe_screen.dart # Asignar equipo/jefe
│   │   ├── quincena_screen.dart     # Exportación quincenal + contabilidad
│   │   ├── dias_quincena_screen.dart
│   │   └── fecha_libre_screen.dart  # Gestión fechas editables
│   ├── obras/
│   │   └── obras_screen.dart  # CRUD obras + asignación operarios
│   ├── partes/
│   │   ├── partes_screen.dart # Listado principal (vistas: lista/semanal/mensual)
│   │   ├── crear_parte_screen.dart  # Dispatcher formularios según rol
│   │   ├── formulario_parte_normal.dart
│   │   ├── formulario_parte_jefe.dart
│   │   ├── formulario_parte_postventa.dart
│   │   ├── editar_partes_screen.dart
│   │   ├── editar_partes_jefe_screen.dart
│   │   ├── informe_jefe_screen.dart # Informe dedicación por rango
│   │   └── resumen_mensual_jefe_screen.dart
│   └── pdf/
│       ├── pdf_screen.dart     # Exportación PDF/ZIP/zipOperario
│       └── report_entry.dart   # Entry point deferred
├── services/
│   ├── api_service.dart        # Cliente HTTP central (Dio + interceptors)
│   ├── auth_service.dart       # Servicio de autenticación Supabase
│   ├── offline_queue_service.dart # Cola offline con UUID
│   └── update_service.dart     # Versión + actualización APK
└── widgets/
    ├── app_drawer.dart         # Menú de navegación
    ├── card_parte.dart         # Tarjeta de parte
    ├── card_parte_jefe.dart    # Tarjeta de parte jefe
    ├── lazy_screen.dart        # Widget genérico para deferred loading
    ├── seccion_firma.dart      # Pad de firma digital
    ├── resumen_semanal.dart    # Resumen semanal
    ├── export_preview.dart     # Vista previa de exportación
    ├── partes_views.dart       # Selector de vistas (lista/semanal)
    └── ... (otros widgets reutilizables)
```

---

## Instalación y Configuración

### Requisitos

- Flutter SDK >= 3.11.3
- Dart SDK >= 3.11.3
- Un backend compatible (Supabase Auth + API REST)

### Variables de entorno (`.env`)

```env
SUPABASE_URL=http://<ip>:8000
SUPABASE_ANON_KEY=<anon-key>
API_URL=http://<ip>:8081/api/v1
APP_URL=http://<ip>:3000
APK_URL=http://<ip>:8000/storage/v1/object/public/instaladores/app-release.apk
```

### Ejecutar en desarrollo

```bash
flutter pub get
flutter run
```

### Build producción

```bash
# Android (ARM)
flutter build apk --release --target-platform android-arm,android-arm64

# Web (HTML renderer)
flutter build web --release --dart-define=FLUTTER_WEB_RENDERER=html

# Docker (Web)
docker build -t gestion-partes .
```

---

## Tipos de Parte de Trabajo

### 1. Parte Normal (OPERARIO / ENCARGADO)
Registro de jornada completa con:
- Fecha, obra, descripción de tareas
- Horas normales
- Especialidad (Electricidad / Fontanería)
- Firma digital (URL + nombre firmado)
- Soporte postventa

### 2. Parte Jefe (JEFE_DE_OBRA)
Distribución porcentual de horas entre múltiples obras:
- Rango de fechas (semanal/mensual)
- Asignación de % a cada obra
- Operarios asignados a su equipo
- Vista combinada con partes normales

### 3. Parte Postventa
Para trabajos de postventa/servicio técnico:
- Selección de operarios específicos
- Obras en modo postventa
- Firma digital

---

## Funcionalidades Clave

### Autenticación Offline
- Login con credenciales contra Supabase Auth
- Persistencia de sesión (JWT + refresh token en secure storage)
- Fallback a perfil cacheado cuando no hay conexión
- Recuperación de contraseña con email + token
- Descarga de nueva versión APK desde la app (web)

### Sincronización Offline
- Cola de partes pendientes en `SharedPreferences` con UUID
- Sincronización automática al recuperar conexión, al iniciar la app, y al volver de segundo plano
- Orden: partes normales → partes jefe → actualizaciones
- Manejo de expiración de JWT antes de sincronizar
- Manejo de errores 4xx (descartar) y 5xx (saltar)
- Indicadores de sincronización en UI

### Exportación
- **PDF**: individual o por obra (generado server-side)
- **ZIP**: múltiples PDFs empaquetados
- **ZIP por operario**: agrupado por trabajador
- **XLSX/CSV**: detalle contable quincenal
- **Vista previa** antes de descargar

### Control de Asistencia
- Detección de días sin parte (ausencias injustificadas)
- Días incompletos (menos de 8h)
- Gestión de ausencias laborales (vacaciones, bajas, paternidad)
- Dashboard de incidencias para administración
- Fechas habilitadas para edición retroactiva

---

## API REST

### Autenticación (Supabase)
| Método | Endpoint | Descripción |
|---|---|---|
| `POST` | `/auth/v1/token?grant_type=password` | Login |
| `POST` | `/auth/v1/token?grant_type=refresh_token` | Refresh token |
| `GET` | `/auth/v1/user` | Datos de usuario |
| `PUT` | `/auth/v1/user` | Actualizar email/password |
| `POST` | `/auth/v1/recover` | Recuperar contraseña |

### Usuarios
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/user/me` | Perfil propio |
| `GET` | `/api/v1/user/all` | Todos los usuarios |
| `POST` | `/api/v1/user/create_user` | Crear usuario |
| `PUT` | `/api/v1/user/update_user/:id` | Actualizar usuario |
| `DELETE` | `/api/v1/user/delete_user/:id` | Eliminar usuario |

### Obras
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/obra` | Listar obras |
| `GET` | `/api/v1/obra/activas` | Obras activas |
| `POST` | `/api/v1/obra` | Crear obra |
| `PUT` | `/api/v1/obra/update_obra/:id` | Actualizar obra |
| `DELETE` | `/api/v1/obra/delete/:id` | Eliminar obra |

### Asignaciones
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/asignaciones/:id/subordinados` | Subordinados de un jefe |
| `PUT` | `/api/v1/asignaciones/asignar_subordinado/:uid/:jefeId` | Asignar subordinado a jefe |
| `GET` | `/api/v1/asignaciones/mis_obras` | Obras del usuario actual |
| `GET` | `/api/v1/asignaciones/obra/:obraId` | Asignaciones de una obra |
| `POST` | `/api/v1/asignaciones/asignar_a_obra/:perfilId/:obraId` | Asignar perfil a obra |
| `PUT` | `/api/v1/asignaciones/asignar_subordinados_batch/:jefeId` | Asignación batch |

### Partes
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/partes/get_partes` | Obtener partes |
| `GET` | `/api/v1/partes/get_partes_jefe` | Partes de jefe |
| `GET` | `/api/v1/partes/buscar` | Buscar partes con filtros |
| `POST` | `/api/v1/partes/new_parte` | Nuevo parte normal |
| `POST` | `/api/v1/partes/new_parte_jefe` | Nuevo parte jefe |
| `PUT` | `/api/v1/partes/update/:id` | Editar parte |
| `PUT` | `/api/v1/partes/update_parte_jefe/:id` | Editar parte jefe |
| `DELETE` | `/api/v1/partes/delete/:id` | Eliminar parte |
| `DELETE` | `/api/v1/partes/delete_jefe/:id` | Eliminar parte jefe |

### Quincena / Contabilidad
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/quincena` | Datos quincena |
| `GET` | `/api/v1/quincena/exportar` | Exportar quincena (XLSX) |
| `GET` | `/api/v1/quincena/contabilidad-detalle-json` | Detalle contable |
| `GET` | `/api/v1/quincena/jefe/contabilidad-detalle-json` | Detalle para jefe |

### Ausencias / Fechas
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/ausencias/dias-sin-parte` | Días sin parte |
| `POST` | `/api/v1/ausencias/laborales` | Registrar ausencia |
| `DELETE` | `/api/v1/ausencias/laborales/:id` | Eliminar ausencia |
| `GET` | `/api/v1/config/fecha-libre` | Fechas editables |
| `POST` | `/api/v1/config/fecha-libre/habilitar/:id` | Habilitar fechas |

### Exportación PDF
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/pdf/partes` | Generar PDF |
| `GET` | `/api/v1/pdf/partes-zip` | ZIP con PDFs |
| `GET` | `/api/v1/pdf/zip-por-operario` | ZIP por operario |

---

## CI/CD

El pipeline (`.github/workflows/deploy.yml`) automatiza en push a `main`:

1. **Setup** Java 17 (Zulu) + Flutter stable
2. **Crear** `.env` desde GitHub Secrets
3. **Restaurar** keystore Android (Base64)
4. **Build** APK release (`android-arm,android-arm64`)
5. **Build** Web release (HTML renderer)
6. **Subir** APK a Supabase Storage (OTA updates, vía curl)
7. **Subir** APK a GitHub Artifacts (retención 7 días)
8. **Docker** build + push a Docker Hub

### Despliegue Web
- **Docker**: imagen nginx:alpine sirviendo `build/web`

---

## Tests

```bash
flutter test
```

Actualmente el proyecto incluye un test de humo básico. Está pendiente ampliar la cobertura.

---

## Legal

Este software ha sido desarrollado por Riu (https://github.com/riu22) y su propiedad 
intelectual pertenece al autor. La empresa dispone de una licencia 
limitada de uso. Cualquier modificación realizada sin el consentimiento 
del autor no es responsabilidad del desarrollador original.
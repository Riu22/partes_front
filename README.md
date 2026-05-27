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
| **PDF** | `pdf` + `printing` |
| **Offline** | Cola offline con `connectivity_plus` |
| **CI/CD** | GitHub Actions → Docker Hub + Supabase Storage |

---

## Roles y Permisos

| Rol | Acceso | Crea Partes | Valida | Gestiona Usuarios | Exporta |
|---|---|---|---|---|---|
| `ADMINISTRACION` | TOTAL | Sí (cualquiera) | Sí | Sí | Sí |
| `GESTION` | TOTAL | Sí (cualquiera) | Sí | Sí | Sí |
| `JEFE_DE_OBRA` | ZONA | % por obras/asignados | Sí | No (gestiona equipo) | Sí (su zona) |
| `ENCARGADO` | OBRA | Sí (su obra) | Sí | No | No |
| `OPERARIO` | INDIVIDUAL | Sí (propio) | No | No | No |

---

## Arquitectura

```
lib/
├── main.dart                  # Entry point
├── config/
│   ├── env.dart               # Config desde .env (URLs, keys)
│   └── router.dart            # Definición de rutas (go_router)
├── core/
│   └── app_shell.dart         # Scaffold principal (AppBar + Drawer)
├── helpers/
│   ├── capture_helper.*       # Captura de pantalla/PDF (platform)
│   ├── download_helper.*      # Descarga de archivos (platform)
│   ├── fecha_helpers.dart     # Formateo de fechas
│   ├── perfil_helpers.dart    # Ordenación de perfiles
│   └── tema_constants.dart    # Colores del tema
├── models/
│   ├── ausencia_info.dart     # Incidencias de asistencia
│   ├── contabilidad_detalle.dart # Desglose de horas
│   ├── obra.dart              # Obra (worksite)
│   ├── parte_trabajo.dart     # Parte de trabajo
│   ├── pdf_export_params.dart # Parámetros de exportación
│   └── perfil.dart            # Perfil de usuario
├── providers/
│   ├── admin_provider.dart    # Estado admin (usuarios, asignaciones)
│   ├── auth_provider.dart     # Autenticación (login/logout/offline)
│   ├── connectivity_provider.dart # Conectividad + sync engine
│   ├── obras_provider.dart    # Obras con caché local
│   ├── partes_provider.dart   # Partes, búsqueda, resúmenes
│   ├── perfiles_provider.dart # Perfiles de usuario
│   └── sync_provider.dart     # Sincronización offline→online
├── screens/
│   ├── login_screen.dart      # Login con offline + descarga APK
│   ├── configurarion_screen.dart # Ajustes de perfil
│   ├── NuevaPasswordScreen.dart  # Restablecer contraseña
│   ├── admin/
│   │   ├── admin_home_screen.dart      # Dashboard incidencias
│   │   ├── usuarios_screen.dart        # CRUD usuarios
│   │   ├── crear_usuarios_screen.dart
│   │   ├── editar_usuarios_screen.dart
│   │   ├── asignar_jefe_screen.dart    # Asignar equipo/jefe
│   │   ├── quincena_screen.dart        # Exportación quincenal
│   │   ├── dias_quincena_screen.dart   # Detalle quincenal
│   │   └── fecha_libre_screen.dart     # Fechas libres
│   ├── obras/
│   │   └── obras_screen.dart  # CRUD obras + asignación
│   ├── partes/
│   │   ├── partes_screen.dart # Listado principal
│   │   ├── crear_parte_screen.dart     # Dispatcher formularios
│   │   ├── formulario_parte_normal.dart # Parte estándar
│   │   ├── formulario_parte_jefe.dart   # Parte porcentual jefe
│   │   ├── formulario_parte_postventa.dart # Postventa
│   │   ├── editar_partes_screen.dart
│   │   ├── editar_partes_jefe_screen.dart
│   │   ├── informe_jefe_screen.dart     # Informe dedicación
│   │   └── resumen_mensual_jefe_screen.dart # Resumen mensual
│   └── pdf/
│       └── pdf_screen.dart     # Exportación PDF/zip
├── services/
│   ├── api_service.dart        # Cliente HTTP central (Dio)
│   ├── auth_service.dart       # Servicio de autenticación
│   ├── offline_queue_service.dart # Cola offline
│   └── update_service.dart     # Versión + actualización
└── widgets/
    ├── app_drawer.dart          # Menú de navegación
    ├── card_parte.dart          # Tarjeta de parte
    ├── card_parte_jefe.dart     # Tarjeta de parte jefe
    ├── seccion_firma.dart       # Pad de firma digital
    ├── resumen_semanal.dart     # Resumen semanal
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
# Android
flutter build apk --release

# Web
flutter build web --release

# Docker (Web)
docker build -t gestion-partes .
```

---

## Tipos de Parte de Trabajo

### 1. Parte Normal (OPERARIO / ENCARGADO)
Registro de jornada completa con:
- Fecha, obra, descripción de tareas
- Horas normales y extraordinarias
- Especialidad (Electricidad / Fontanería)
- Firma digital del operario
- Validación del encargado/jefe

### 2. Parte Jefe (JEFE_DE_OBRA)
Distribución porcentual de horas entre múltiples obras:
- Rango de fechas (semanal/mensual)
- Asignación de % a cada obra (eléctrico + mecánico)
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
- Login con credenciales almacenadas localmente
- Fallback a caché cuando no hay conexión
- Descarga de nueva versión APK desde la app (Web)

### Sincronización Offline
- Cola de partes pendientes en `SharedPreferences`
- Sincronización automática al recuperar conexión
- Orden: partes normales → partes jefe → actualizaciones
- Manejo de expiración de JWT antes de sincronizar

### Exportación
- **PDF**: individual o por obra
- **ZIP**: múltiples PDFs empaquetados
- **ZIP por operario**: agrupado por trabajador
- **CSV**: detalle contable quincenal
- Vista previa antes de descargar

### Control de Asistencia
- Detección de días sin parte (ausencias injustificadas)
- Días incompletos (menos de 8h)
- Gestión de ausencias laborales (vacaciones, bajas)
- Dashboard de incidencias para administración

---

## API REST

### Autenticación
| Método | Endpoint | Descripción |
|---|---|---|
| `POST` | `/auth/v1/token` | Login Supabase |
| `GET` | `/auth/v1/user` | Datos de usuario |
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
| `PUT` | `/api/v1/asignaciones/asignar_encargado/:uid/:jefeId` | Asignar encargado a jefe |
| `GET` | `/api/v1/asignaciones/mis_obras` | Obras del usuario actual |

### Partes
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/partes/get_partes` | Obtener partes |
| `GET` | `/api/v1/partes/get_partes_jefe` | Partes de jefe |
| `POST` | `/api/v1/partes/new_parte` | Nuevo parte normal |
| `POST` | `/api/v1/partes/new_parte_jefe` | Nuevo parte jefe |
| `PUT` | `/api/v1/partes/update/:id` | Editar parte |
| `DELETE` | `/api/v1/partes/delete/:id` | Eliminar parte |

### Quincena / Contabilidad
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/quincena` | Datos quincena |
| `GET` | `/api/v1/quincena/exportar` | Exportar quincena |
| `GET` | `/api/v1/quincena/contabilidad-detalle-json` | Detalle contable |

### Ausencias
| Método | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/v1/ausencias/dias-sin-parte` | Días sin parte |
| `POST` | `/api/v1/ausencias/laborales` | Registrar ausencia |
| `DELETE` | `/api/v1/ausencias/laborales/:id` | Eliminar ausencia |

---

## CI/CD

El pipeline (`.github/workflows/deploy.yml`) automatiza:

1. **Build** de APK release firmado
2. **Build** de Web release
3. **Subida** del APK a Supabase Storage (OTA updates)
4. **Docker** build + push a Docker Hub
5. **Vercel** deploy (SPA con rewrites)

---

## Despliegue

### Web (Vercel)
```bash
flutter build web --release
vercel --prod
```

### Web (Docker)
```bash
flutter build web --release
docker build -t gestion-partes .
docker run -p 80:80 gestion-partes
```

### Android
```bash
flutter build apk --release
# APK generado en build/app/outputs/flutter-apk/
```

---

## Tests

```bash
flutter test
```

Actualmente el proyecto incluye un test de humo básico. Está pendiente ampliar la cobertura.

---

## Licencia

Uso interno.

# Perdiem

<p align="center">
  <a href="https://github.com/devflores-ka/PerDiem">
    <img alt="Flutter" src="https://img.shields.io/static/v1?label=flutter&message=perdiem&color=blue&style=for-the-badge&logo=Flutter" />
  </a>
  <a href="https://github.com/devflores-ka/PerDiem/issues">
  <img alt="Issues" src="https://img.shields.io/badge/issues-private-blue" />
  </a>
  <a href="https://github.com/devflores-ka/PerDiem/blob/main/LICENSE">
  <img alt="Licencia propietaria" src="https://img.shields.io/badge/licencia-Propietaria-red" />
</a>
</p>

## 🚀 Conecta oferentes y demandantes de servicios en Chile

<p align="center">
  <img src="assets/logo.png" alt="Perdiem Logo" width="150" />
</p>

**Perdiem** es una aplicación móvil orientada a la economía colaborativa que facilita la conexión entre personas que ofrecen y demandan servicios comunes como gasfitería, albañilería, fletes, entre otros. Promoviendo el trabajo independiente y la inclusión digital en Chile.

---

## 📱 ¿Qué es Perdiem?

Perdiem nace para cubrir la necesidad de una plataforma nacional que conecte eficientemente a trabajadores independientes con potenciales clientes en Chile. Con enfoque inicial en Iquique y alcance nacional, la app busca eliminar barreras de acceso, reducir la informalidad y dar mayor visibilidad a quienes viven de estos oficios.

### ✨ Características principales

- **🏠 Inicio**: Pantalla principal con listado público de trabajos disponibles
- **📝 Publicación de ofertas**: Formulario para crear y publicar servicios
- **🗺️ Búsqueda geolocalizada**: Mapa interactivo con filtros por categoría
- **💬 Mensajería integrada**: Chat automático entre oferentes y demandantes
- **📊 Gestión de trabajos**: Seguimiento de ofertas y estados de trabajo
- **👤 Perfil de usuario**: Gestión de información, habilidades y preferencias
- **💳 Opciones de pago**: Efectivo y pagos digitales integrados
- **🔒 Verificación de usuarios**: Sistema de validación de identidad

---

## 🛠️ Stack Tecnológico y Dependencias Clave

- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (`supabase_flutter`)
- **Mapas**: `mapbox_maps_flutter`, `google_maps_flutter`, `flutter_map`
- **Geolocalización**: `geolocator`
- **Mensajería**: `flutter_chat_ui`, `flutter_chat_types`
- **Autenticación y Login**: `flutter_login`
- **HTTP y Networking**: `dio`, `http`
- **Almacenamiento y Archivos**: `file_picker`, `file_saver`, `path_provider`, `open_filex`
- **Firebase**: `firebase_core`, `firebase_messaging`
- **Utilidades**: `shared_preferences`, `provider`, `intl`, `timeago`
- **Otros**: `flutter_svg`, `image_picker`, `permission_handler`, `url_launcher`, `share_plus`

---

## 📋 Requisitos

- `Dart >=2.19.0`
- `Flutter >=3.0.0`
- Proyecto de [Supabase](https://supabase.com)
- Cuenta de [Mapbox](https://mapbox.com)

---

## 🚀 Configuración inicial

### 1. Crear proyecto Supabase

```bash
# Instalar Supabase CLI
npm install -g supabase

# Iniciar sesión
supabase login

# Crear nuevo proyecto
supabase projects create perdiem-app

# Obtener referencia del proyecto
supabase projects list

# Obtener claves API
supabase projects api-keys


### 2. Configurar el proyecto Flutter

1. Clona el repositorio:
```bash
git clone https://github.com/lmaglotflores/perdiem.git
cd perdiem
```

2. Instala las dependencias:
```bash
flutter pub get
```

3. Configura las variables de entorno en `lib/config/supabase_config.dart`:
```dart
const String supabaseUrl = 'YOUR_SUPABASE_URL';
const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 3. Configurar base de datos

Ejecuta los scripts de preparación para configurar automáticamente las tablas, reglas de seguridad y buckets necesarios:

#### Linux/macOS:
```bash
cd ./scripts/
./setup_database.sh -h "your-postgres-host" -p your-postgres-port -d "your-postgres-database" -U "your-postgres-user"
```

#### Windows:
```powershell
cd .\scripts\
.\setup_database.ps1 -hostname "your-postgres-host" -port your-postgres-port -database "your-postgres-database" -user "your-postgres-user"
```

### 4. Configurar esquemas en Supabase

Desde el dashboard de Supabase, agrega el esquema `services` a la exposición de la API:

1. Ve a **Settings** > **API**
2. En **Schema exposure**, agrega `chats` y `jobs`
3. Guarda la configuración

---

## 🏗️ Arquitectura de la base de datos

### Tablas principales

#### `chats.users`
- Información de usuarios registrados
- Habilidades y especialidades
- Estado de verificación

#### `jobs.offers`
- Ofertas de trabajo publicadas
- Detalles del servicio requerido
- Ubicación referencial

#### `jobs.offer_applicants`
- Postulaciones a ofertas
- Estado de aplicación
- Relación oferente-demandante

#### `chats.messages`
- Sistema de mensajería
- Comunicación entre usuarios
- Historial de conversaciones

#### `jobs.reviews`
- Sistema de calificaciones
- Reseñas de servicios completados
- Reputación de usuarios

---

## 🔐 Seguridad (RLS - Row Level Security)

### Políticas de acceso

#### Tabla `chats.users`
- **INSERT**: Solo trigger automático desde auth.users
- **SELECT**: Usuarios autenticados
- **UPDATE**: Solo el propio usuario
- **DELETE**: Restringido

#### Tabla `jobs.offers`
- **INSERT**: Usuarios autenticados
- **SELECT**: Público (ofertas activas)
- **UPDATE**: Solo el creador de la oferta
- **DELETE**: Solo el creador de la oferta

#### Tabla `jobs.offer_applicants`
- **INSERT**: Usuarios autenticados
- **SELECT**: Oferente y demandante involucrados
- **UPDATE**: Oferente y demandante involucrados
- **DELETE**: Solo el aplicante

#### Tabla `chats.messages`
- **INSERT**: Usuarios involucrados en la conversación
- **SELECT**: Usuarios involucrados en la conversación
- **UPDATE**: Remitente del mensaje
- **DELETE**: Remitente del mensaje

---

## 📱 Pantallas implementadas

| Pantalla | Descripción | Estado |
|----------|-------------|--------|
| **Inicio** | Listado público de trabajos | ✅ |
| **Crear Oferta** | Formulario de publicación | ✅ |
| **Mapa** | Búsqueda geolocalizada | ✅ |
| **Chat** | Mensajería integrada | ✅ |
| **Mis Trabajos** | Gestión de ofertas | ✅ |
| **Perfil** | Información de usuario | ✅ |
| **Verificación** | Validación de identidad | 🔄 |
| **Pagos** | Integración de pagos | 📋 |

**Leyenda:**
- ✅ Implementado
- 🔄 En desarrollo
- 📋 Planificado

---

## 🎯 Roadmap del proyecto

### Fase 1 - MVP (3 meses) ✅
- [x] Diseño de interfaces
- [x] Sistema de autenticación
- [x] Publicación de ofertas
- [x] Búsqueda por geolocalización
- [x] Sistema de mensajería
- [x] Gestión básica de trabajos
- [x] Perfiles de usuario

### Fase 2 - Mejoras (Mes 4-6)
- [ ] Sistema de calificaciones
- [ ] Verificación de identidad
- [ ] Integración de pagos
- [ ] Notificaciones push
- [ ] Optimización de rendimiento

### Fase 3 - Escalabilidad (Mes 7+)
- [ ] Aplicación iOS
- [ ] Versión web
- [ ] Panel administrativo
- [ ] Analytics y métricas
- [ ] Expansión nacional

---

## 💰 Modelo de negocio

### Estrategia de monetización
- **Fase MVP**: Gratuito para todos los usuarios
- **Fase de crecimiento**: Comisión por transacciones completadas
- **Servicios premium**: Verificación prioritaria, destacados, etc.

### Presupuesto inicial
- **Desarrollo**: $300.000 CLP (3 meses)
- **Infraestructura**: Gratuita durante MVP
- **Escalamiento**: ~$25 USD/mes (Supabase Pro)

---

## 👥 Equipo

| Rol | Nombre | Responsabilidad |
|-----|--------|----------------|
| **Director del Proyecto** | Luciano Flores | Desarrollo técnico y planificación |
| **Patrocinador** | Roberto Larenas | Decisiones de negocio y presupuesto |
| **Stakeholder** | Pamela Reyna | Validación de requerimientos |

---

## 🤝 Contribución

Este proyecto está en desarrollo activo. Si quieres contribuir:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agrega nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

---

## 📄 Licencia

Este proyecto está bajo la Licencia Apache 2.0. Ver el archivo [LICENSE](LICENSE) para más detalles.

---

## 📞 Contacto

- **Desarrollador**: Luciano Flores
- **Email**: [luciano.flores@example.com](mailto:luciano.flores@example.com)
- **Ubicación**: Iquique, Chile

---

## 🙏 Agradecimientos

- [Supabase](https://supabase.com) por la infraestructura backend
- [Flutter](https://flutter.dev) por el framework de desarrollo
- [Mapbox](https://mapbox.com) por los servicios de mapas
- Comunidad de desarrolladores de Flutter y Dart

---

**¿Necesitas un servicio? ¿Ofreces uno? ¡Perdiem te conecta!** 🔗

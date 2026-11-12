# Lapso Jornada · app móvil

App de reloj checador **Lapso Jornada** para iOS y Android, en Flutter. La hace FLU3NCE.

Este repositorio es el frontend de la app. Habla con la API de Lapso según el contrato 0.9.0, que vive en el repositorio `Lapso-Contrato` (carpeta `api/`).

## Estado

| Parte | Estado |
| --- | --- |
| Pantallas y navegación de la app actual | Hechas |
| Conexión con la API (22 de las 34 operaciones del contrato) | Escrita, **sin probar contra el servidor** |
| Cámara, lector de QR y ubicación | Integradas con plugins, **sin probar en un teléfono** |
| Registro sin conexión con cola cifrada | Hecho. El envío ocurre con la app abierta, no en segundo plano |
| Correcciones, periodo, avisos, horario y recuperar PIN | Tienen servicio en el contrato; faltan las pantallas |
| Requisitos de App Store y Google Play | Revisados: [docs/tiendas.md](docs/tiendas.md) |
| Carpetas `android/` e `ios/` | Se generan con un comando: [docs/plataformas.md](docs/plataformas.md) |

**Importante: este código no se ha compilado.** Se escribió en un entorno sin el SDK de Flutter. Se revisó la sintaxis de todos los archivos con un analizador sintáctico de Dart y se cotejaron los íconos y las API menos comunes contra el código fuente de Flutter, pero `flutter analyze` y `flutter test` no se han corrido, y el uso de los plugins se escribió de memoria. La primera compilación va a pedir ajustes, sobre todo en `lib/platform/`.

## Cómo correrla

Requiere Flutter 3.24 o posterior.

```bash
# 1. Carpetas de plataforma (no sobrescribe lo que ya existe)
flutter create . --platforms=android,ios --org com.flu3nce --project-name lapso_jornada

# 2. Permisos y textos de permiso: sigue docs/plataformas.md

# 3. Dependencias, análisis y pruebas
flutter pub get
flutter analyze
flutter test

# 4. Correr
flutter run                                   # contra el servidor de validación
flutter run --dart-define=LAPSO_DEMO=true     # demostración sin servidor
```

El servidor se cambia con `--dart-define=LAPSO_SERVER=https://...`. Por omisión es `https://validacion.lapsojornada.mx`.

### Modo de demostración

Con `LAPSO_DEMO=true` la app usa un servidor simulado en memoria y capturas simuladas, para revisar el diseño y los flujos sin backend. Nunca se usa en una compilación para tienda.

| Dato | Valor |
| --- | --- |
| Código de organización | `campo-prueba` |
| Número de empleado | `GIL-001` |
| PIN | `482913` |
| PIN temporal (obliga a cambiarlo) | `735194` |

En **Más** aparece *Herramientas de demostración* para provocar estados difíciles: sin conexión, sin permiso de ubicación, reloj del teléfono adelantado (registro rechazado) y jornada de más de 16 horas.

## Estructura

```
lib/
  main.dart              Arranque: app real o demostración
  app.dart               MaterialApp y RootGate (qué pantalla toca según la sesión)
  config.dart            Servidor, versión y límites; se ajustan con --dart-define
  theme/                 Colores, tipografía y tema
  domain/                Modelos, reglas y formatos. Dart puro
  data/
    lapso_api.dart       Contrato con el servidor, como lo ve la app
    http_lapso_api.dart  Cliente HTTP real (cookie de sesión, errores, copia sin red)
    mappers.dart         JSON del contrato 0.9.0 ⇄ modelos de la app
    fake_lapso_api.dart  Servidor simulado para demostración y pruebas
    key_value_store.dart Almacén del teléfono (puerto)
  platform/
    device_capture.dart       Ubicación, cámara y QR (puerto y versión simulada)
    real_device_capture.dart  Con geolocator, image_picker y mobile_scanner
    secure_store.dart         Con flutter_secure_storage
  state/                 AppController (estado de toda la app) y AppScope
  widgets/               Componentes compartidos
  screens/               acceso/, jornada/, historial/ y mas/
test/                    Reglas, formatos, traducción del contrato, controlador y un recorrido
docs/
  contrato.md            Qué operación usa cada pantalla y qué sigue abierto con backend
  tiendas.md             Reglas de App Store y Google Play y cómo se cumplen
  plataformas.md         Permisos, textos e íconos de iOS y Android
```

Los plugins quedan detrás de dos puertos (`DeviceCapture` y `KeyValueStore`), así que un cambio de plugin o de su versión se resuelve en `lib/platform/` sin tocar pantallas.

### Navegación

`RootGate` decide la pantalla raíz:

1. Sin organización → **Tu organización**
2. Sin sesión → **Inicio de sesión** (o **Cuenta bloqueada**)
3. PIN temporal → **Cambia tu PIN**
4. Con sesión → tres pestañas: **Mi jornada**, **Historial** y **Más**

Un registro recorre: aceptación de capturas (la primera vez) → QR del centro → ubicación y foto → envío → comprobante. Cada paso aparece solo si el centro pide esa captura para ese tipo de registro. Nada bloquea: si algo falla o la persona no acepta, el registro se guarda y queda marcado.

## Dependencias

| Paquete | Para qué |
| --- | --- |
| `flutter_secure_storage` | Sesión y cola sin conexión cifradas |
| `geolocator` | Una lectura de ubicación en primer plano al registrar |
| `image_picker` | Foto con la cámara frontal |
| `mobile_scanner` | Lector de QR |
| `url_launcher` | Abrir la web de Lapso, el correo y el teléfono de contacto |

El cliente HTTP usa `dart:io`, sin paquetes. No hay analítica, publicidad ni SDK de terceros que recolecten datos.

## Criterios de diseño

- Colores, radios y tipografía en `lib/theme/tokens.dart`. Montserrat 700 para títulos y cifras, Inter para el resto (incluidas en `assets/fonts/`).
- Accesibilidad (WCAG 2.2 AA): contraste de texto de 4.5:1 o más y de 3:1 en bordes de controles; áreas táctiles de 44 px o más; texto de 12 px o más; ningún estado se comunica solo con color; etiquetas para lector de pantalla en cifras, relojes y botones de ícono.
- Una sola acción principal por pantalla y textos en español de México, de tú.

Diseño de las pantallas: https://claude.ai/artifact/MGcAGSSXchQzLiRhu1jFQF (enlace privado; pide acceso a quien mantiene este repositorio).

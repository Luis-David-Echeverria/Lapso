# Lapso Jornada · app móvil

Frontend en Flutter de la app de reloj checador **Lapso Jornada** (iOS y Android), de FLU3NCE.

Reproduce las pantallas y la navegación de la app actual (versión 0.1.6 de pruebas) con el diseño nuevo. Todavía **no se conecta al servidor**: corre contra un servidor simulado en memoria, con datos de prueba, para poder recorrer todos los flujos sin acceso al backend.

## Estado

| Parte | Estado |
| --- | --- |
| Pantallas y navegación (las 26 del diseño, contando estados) | Hechas |
| Reglas de la jornada, del PIN y formatos | Hechas, con pruebas |
| Servidor | Simulado (`FakeLapsoApi`). Falta la implementación HTTP |
| Cámara, lector de QR y GPS | Simulados. Falta integrar los plugins |
| Cola sin conexión | En memoria. Falta guardarla cifrada y enviarla en segundo plano |
| Carpetas `android/` e `ios/` | No están en el repo: se generan con un comando (abajo) |

**Importante:** este código se escribió sin poder compilarlo ni analizarlo (el entorno donde se generó no tenía el SDK de Flutter). Se revisó la sintaxis de todos los archivos con un analizador sintáctico de Dart, y se cotejaron contra el código fuente de Flutter estable todos los íconos y los parámetros menos comunes de los widgets, pero `flutter analyze` y `flutter test` **no se han corrido**. Es de esperar que la primera compilación pida ajustes menores.

## Cómo correrla

Requiere Flutter 3.24 o posterior (Dart 3.5+).

```bash
# 1. Genera las carpetas de plataforma. No sobrescribe lo que ya existe.
flutter create . --platforms=android,ios --org com.flu3nce --project-name lapso_jornada

# 2. Dependencias, análisis y pruebas
flutter pub get
flutter analyze
flutter test

# 3. Corre en un emulador o teléfono
flutter run
```

La app de pruebas actual usa el identificador `com.flu3nce.jornada.pruebas`. Si esta versión debe instalarse encima de aquella, hay que poner ese mismo identificador en Android (`applicationId`) y firmar con la misma llave.

Los íconos de la app están en `assets/icon/` (`app_icon.png` y `app_icon_foreground.png`, 1024 px). Falta aplicarlos a las carpetas de plataforma, a mano o con `flutter_launcher_icons`.

## Datos de prueba

| Dato | Valor |
| --- | --- |
| Código de organización | `campo-prueba` |
| Número de empleado | `GIL-001` |
| PIN | `482913` |
| PIN temporal (obliga a cambiarlo) | `735194` |

Con tres PIN incorrectos seguidos la cuenta se bloquea 15 minutos. El bloqueo vive en memoria: reiniciar la app lo quita.

En la pestaña **Más** aparece la sección *Herramientas de demostración* (solo con el servidor simulado) para provocar estados difíciles:

- **Sin conexión:** los registros se guardan como pendientes y luego se envían desde *Mi jornada*.
- **Permiso de ubicación:** apágalo para ver el registro sin ubicación.
- **Adelantar el reloj 17 horas:** con una jornada abierta dispara el aviso de jornada larga.
- **Registro rechazado:** adelanta el reloj, activa *Sin conexión*, registra, vuelve a la hora real, quita *Sin conexión* y envía los pendientes.

## Estructura

```
lib/
  main.dart              Arranque. Aquí se elige el servidor (simulado o real)
  app.dart               MaterialApp y RootGate (qué pantalla toca según la sesión)
  config.dart            Versión, direcciones y datos pendientes de definir
  theme/                 Colores, tipografía y tema (tokens.dart, theme.dart)
  domain/                Modelos, reglas de negocio y formatos. Dart puro, sin Flutter
  data/                  LapsoApi (contrato) y FakeLapsoApi (servidor simulado)
  state/                 AppController (estado de toda la app) y AppScope
  widgets/               Componentes compartidos
  screens/
    acceso/              Organización, inicio de sesión, cuenta bloqueada, cambio de PIN
    jornada/             Mi jornada, lector QR, evidencia, comprobante, pendientes
    historial/           Historial día por día
    mas/                 Más, mis datos de captura, privacidad, actualización
test/                    Pruebas de reglas, formatos, controlador y un recorrido básico
```

No hay dependencias de terceros: solo `flutter`, `flutter_localizations`, `flutter_test` y `flutter_lints`. El estado se maneja con `ChangeNotifier` + `InheritedNotifier` y la navegación con `Navigator`.

### Navegación

`RootGate` decide la pantalla raíz:

1. Sin organización → **Tu organización**
2. Sin sesión → **Inicio de sesión** (o **Cuenta bloqueada**)
3. PIN temporal → **Cambia tu PIN** (obligatorio)
4. Con sesión → tres pestañas: **Mi jornada**, **Historial** y **Más**

Registrar una entrada o una salida recorre: lector QR → ubicación y foto → envío → comprobante. Cada paso de evidencia aparece solo si el centro lo pide; si alguno falla, el registro se puede guardar sin él y queda marcado.

## Conectar el servidor real

1. Crea una clase que implemente `LapsoApi` (`lib/data/lapso_api.dart`) con llamadas HTTP.
2. En `lib/main.dart`, cambia `FakeLapsoApi()` por esa clase y pon `demoTools: false`.

Cada método del contrato corresponde a operaciones que la app 0.1.6 ya consume en `https://validacion.lapsojornada.mx/api/v1`:

| Método | Operación del servidor |
| --- | --- |
| `findOrganization` | `GET /tenants/{slug}/public`, `GET /branding/current` |
| `login` | `POST /auth/pin` |
| `changePin` | `POST /auth/pin/change` |
| `logout` | `POST /auth/logout` |
| `workCenter` | `GET /me/today` |
| `history` | `GET /me/timesheets` |
| `register` | `POST /time-events/clock-in`, `clock-out`, `break-start`, `break-end`; `POST /evidence/photos` |
| `sync` | `POST /time-events/sync` |
| `consents` | `GET /me/consents` |
| `setConsent` | `POST /me/consents`, `POST /me/consents/{capability}/revoke` |
| `evidenceViews` | `GET /me/evidence-views` |
| `rejections` | `GET /me/offline/rejections` |

Las rutas salen del análisis del APK, no de documentación oficial: los métodos HTTP, los cuerpos y las respuestas hay que confirmarlos con backend. Faltan en el contrato los documentos legales (`GET /public/legal/{kind}`), las fotos (`GET /me/events/{event_id}/photo`) y la lectura del QR del centro (`GET /qr/{token}`).

## Puntos de integración pendientes

Están marcados en el código con el comentario `Punto de integración`.

| Qué | Dónde | Sugerencia |
| --- | --- | --- |
| Lector de QR | `screens/jornada/escaner_qr_screen.dart` | `mobile_scanner` |
| Cámara frontal y foto | `screens/jornada/evidencia_screen.dart`, `foto_preview_screen.dart` | `camera` |
| Lectura de ubicación | `AppController.readLocation` | `geolocator` |
| Abrir la web | `screens/web_handoff.dart` | `url_launcher` |
| Cola sin conexión cifrada y envío en segundo plano | `AppController` (`_pending`, `syncPending`) | `flutter_secure_storage`, `workmanager` |
| Recordar organización y sesión | `AppController` | `flutter_secure_storage` |
| Documentos legales | `screens/mas/privacidad_screen.dart` | `GET /public/legal/{kind}` |
| Fotos del trabajador | `screens/mas/mis_fotos_screen.dart` | `GET /me/events/{event_id}/photo` |
| Actualización fuera de tienda | `screens/mas/actualizacion_screen.dart` | Descarga, verificación SHA-256 e instalador |

## Supuestos por confirmar

Se tomaron estas decisiones sin poder verlas en el servidor:

- El bloqueo ocurre al **tercer** PIN incorrecto (los 15 minutos sí salen de la app actual).
- Las **pausas** y reanudaciones se registran sin evidencia; solo la entrada y la salida piden QR, ubicación y foto.
- Después de terminar una jornada se puede registrar **otra entrada** el mismo día.
- No se puede **cerrar sesión** con registros pendientes de enviar, para no perderlos.
- La meta de la barra de avance es el horario del centro menos el tiempo de comida.
- Los datos de **soporte** (correo y teléfono) están vacíos en `lib/config.dart`; la pantalla de ayuda no los muestra hasta que existan.

## Criterios de diseño

- Colores, radios y tipografía en `lib/theme/tokens.dart`. Tipografías: Montserrat 700 para títulos y cifras, Inter para el resto (incluidas en `assets/fonts/`).
- Accesibilidad (WCAG 2.2 AA): contraste de texto de 4.5:1 o más y de 3:1 en bordes de controles; áreas táctiles de 44 px o más; texto de 12 px o más; ningún estado se comunica solo con color; etiquetas para lector de pantalla en cifras, relojes y botones de ícono; el PIN se escribe con teclado propio.
- Una sola acción principal por pantalla y textos en español de México, de tú.

## Diseño y documentación

- Diseño de las pantallas (lienzo): https://claude.ai/artifact/MGcAGSSXchQzLiRhu1jFQF
- Documentación funcional (casos de uso, navegación, reglas, operaciones del servidor, propuestas): https://claude.ai/artifact/515W41wSvC8KSHcY2c1BsF

Ambos enlaces son privados; pide acceso a quien mantiene este repositorio.

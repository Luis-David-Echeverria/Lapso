# Configuración de iOS y Android

Las carpetas `android/` e `ios/` no están en el repositorio. Se generan con:

```bash
flutter create . --platforms=android,ios --org com.flu3nce --project-name lapso_jornada
```

Después hay que aplicar esto a mano. Sin estos cambios la app compila, pero la cámara y la ubicación no funcionan y las tiendas la rechazan.

## Android

`android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

En `<application>` agrega `android:allowBackup="false"`, para que la sesión y la cola sin conexión no salgan del teléfono en un respaldo.

**No declarar:** `ACCESS_BACKGROUND_LOCATION`, `REQUEST_INSTALL_PACKAGES`, `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE` ni `WRITE_EXTERNAL_STORAGE`. La app no los usa y cada uno obliga a justificarlo ante Google Play.

`android/app/build.gradle`:

- `minSdk 23` (lo piden el lector de QR y el almacén cifrado).
- `targetSdk` y `compileSdk`: el nivel que Google Play exija el día de publicar.
- `applicationId`: el definitivo. La app de pruebas anterior usa `com.flu3nce.jornada.pruebas`; para instalarse encima necesita el mismo identificador y la misma llave de firma.

## iOS

`ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Lapso Jornada usa la cámara para leer el código QR de tu centro de trabajo y para tomar la foto de tu registro de jornada.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Lapso Jornada lee tu ubicación una sola vez cuando registras tu jornada, para acreditar que registraste en tu centro de trabajo.</string>
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

El plugin de la cámara (`image_picker`) incluye código de galería y de video aunque la app no lo use, y Apple revisa que existan sus textos. Agrega también:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Lapso Jornada no usa tu galería. La foto de tu registro se toma con la cámara.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Lapso Jornada no graba audio.</string>
```

**No declarar** `NSLocationAlwaysAndWhenInUseUsageDescription` ni modos en segundo plano (`UIBackgroundModes`).

Versión mínima de iOS: 13.

## Íconos

Están en `assets/icon/` a 1,024 px (`app_icon.png` y `app_icon_foreground.png`, este último para el ícono adaptable de Android con fondo blanco). Se aplican a mano o con el paquete `flutter_launcher_icons`.

## Compilar

```bash
# Contra el servidor de validación (valor por omisión)
flutter run

# Contra otro servidor
flutter run --dart-define=LAPSO_SERVER=https://app.ejemplo.mx

# Demostración sin servidor, con capturas simuladas. Nunca para tienda.
flutter run --dart-define=LAPSO_DEMO=true
```

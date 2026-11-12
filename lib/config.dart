/// Valores de configuración de la app. Se pueden cambiar al compilar con
/// `--dart-define`, sin tocar el código.
library;

/// Versión que se muestra en Más. Debe coincidir con `pubspec.yaml`.
const String kAppVersion = '0.3.0';

/// Servidor de Lapso. Por omisión, el ambiente de validación.
///
/// `flutter build ... --dart-define=LAPSO_SERVER=https://app.ejemplo.mx`
const String kServerUrl = String.fromEnvironment(
  'LAPSO_SERVER',
  defaultValue: 'https://validacion.lapsojornada.mx',
);

/// Todas las rutas de la API cuelgan de aquí.
const String kApiBaseUrl = '$kServerUrl/api/v1';

/// Web de Lapso, para los trámites que todavía no viven en la app.
const String kWebBaseUrl = kServerUrl;

/// Modo de demostración: servidor simulado en memoria y capturas simuladas.
/// Nunca en una compilación para tienda.
///
/// `flutter run --dart-define=LAPSO_DEMO=true`
const bool kDemoMode = bool.fromEnvironment('LAPSO_DEMO');

/// Días de historial que la app consulta (el máximo por consulta del
/// servidor) y que cubre «Mis fotos».
const int kHistoryDays = 62;

/// Límites de la foto de evidencia que acepta el servidor.
const int kPhotoMaxBytes = 300 * 1024;
const double kPhotoMaxSide = 1024;

/// Tipos de texto legal públicos.
const String kLegalPrivacy = 'AVISO_PRIVACIDAD';
const String kLegalRetention = 'POLITICA_CONSERVACION';
const String kLegalRecord = 'MEDIO_REGISTRO';

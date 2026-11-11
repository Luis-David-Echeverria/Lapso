/// Valores de configuración de la app.
///
/// Los marcados como pendientes son datos que todavía debe dar FLU3NCE.
library;

/// Versión que se muestra en Más. Debe coincidir con `pubspec.yaml`.
const String kAppVersion = '0.2.0';

/// Canal de distribución.
const String kAppChannel = 'pruebas';

/// Servidor de validación. Solo lo usa la implementación HTTP de `LapsoApi`.
const String kApiBaseUrl = 'https://validacion.lapsojornada.mx/api/v1';

/// Web de Lapso, para los trámites que no viven en la app.
const String kWebBaseUrl = 'https://validacion.lapsojornada.mx';

/// Días que el trabajador puede consultar sus fotos.
const int kPhotoRetentionDays = 62;

/// Pendiente: correo de soporte.
const String? kSupportEmail = null;

/// Pendiente: teléfono de soporte.
const String? kSupportPhone = null;

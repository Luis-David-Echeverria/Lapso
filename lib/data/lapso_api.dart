import 'dart:typed_data';

import '../domain/models.dart';

/// Código de [LapsoException] cuando no se pudo llegar al servidor.
const String kNetworkError = 'NETWORK';

/// Error de una operación. [message] está en español y se puede mostrar.
///
/// [code] es el `code` estable del servidor (`ACCOUNT_LOCKED`,
/// `SESSION_ALREADY_OPEN`, ...) o [kNetworkError] si no hubo conexión.
class LapsoException implements Exception {
  const LapsoException(
    this.message, {
    this.code = 'ERROR',
    this.status,
    this.retryAfter,
  });

  const LapsoException.network()
      : message = 'No hay conexión con el servidor. Revisa tu internet e '
            'inténtalo de nuevo.',
        code = kNetworkError,
        status = null,
        retryAfter = null;

  final String message;
  final String code;
  final int? status;

  /// Espera que pide el servidor (encabezado `Retry-After`).
  final Duration? retryAfter;

  bool get isNetwork => code == kNetworkError;
  bool get isUnauthenticated => code == 'UNAUTHENTICATED';

  @override
  String toString() => 'LapsoException($code): $message';
}

enum LoginStatus { ok, wrongCredentials, locked, noWorkerProfile }

class LoginResult {
  const LoginResult(this.status, {this.message});
  final LoginStatus status;
  final String? message;
}

/// Referencia de reloj para los registros sin conexión: la última hora del
/// servidor conocida y lo que marcaba el teléfono en ese instante.
class ClockReference {
  const ClockReference({
    required this.serverTime,
    required this.deviceTime,
    required this.monotonicMs,
    required this.monotonicSession,
  });

  final DateTime serverTime;
  final DateTime deviceTime;
  final int monotonicMs;
  final String monotonicSession;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'server_time': serverTime.toUtc().toIso8601String(),
        'device_time': deviceTime.toUtc().toIso8601String(),
        'monotonic_ms': monotonicMs,
        'monotonic_session': monotonicSession,
      };

  static ClockReference? fromJson(Object? json) {
    if (json is! Map) return null;
    final DateTime? server = DateTime.tryParse('${json['server_time']}');
    final DateTime? device = DateTime.tryParse('${json['device_time']}');
    final Object? ms = json['monotonic_ms'];
    final Object? session = json['monotonic_session'];
    if (server == null || device == null || ms is! int || session is! String) {
      return null;
    }
    return ClockReference(
      serverTime: server,
      deviceTime: device,
      monotonicMs: ms,
      monotonicSession: session,
    );
  }
}

/// Un registro tal como lo arma el teléfono, antes de que el servidor lo
/// acepte. Sirve igual para el envío en línea y para la cola sin conexión.
class RegisterDraft {
  const RegisterDraft({
    required this.key,
    required this.type,
    required this.declaredAt,
    this.pauseType,
    this.qr,
    this.location,
    this.photoId,
    this.photoStatus,
    this.monotonicMs,
    this.monotonicSession,
    this.clockReference,
    this.evidence = Evidence.none,
  });

  /// UUID generado una vez por toque. Es la `Idempotency-Key` en línea y el
  /// `idempotency_key` del evento sin conexión.
  final String key;
  final EventType type;
  final PauseType? pauseType;

  /// Hora del teléfono al tocar.
  final DateTime declaredAt;
  final QrReading? qr;
  final LocationReading? location;

  /// Identificador de la foto ya subida (vale 5 minutos).
  final String? photoId;

  /// Motivo de no tener foto: `DENEGADO`, `NO_SOPORTADO`, `NO_DISPONIBLE` o
  /// `FALLO_SUBIDA`.
  final String? photoStatus;
  final int? monotonicMs;
  final String? monotonicSession;
  final ClockReference? clockReference;

  /// Cómo se muestra la evidencia mientras el registro sigue en el teléfono.
  final Evidence evidence;

  /// El registro como evento pendiente, para mostrarlo en las pantallas.
  TimeEvent toPendingEvent() => TimeEvent(
        id: key,
        type: type,
        at: declaredAt,
        pauseType: pauseType,
        offline: true,
        evidence: evidence,
      );
}

class RegisterResult {
  const RegisterResult({required this.event, required this.today});
  final TimeEvent event;
  final TodaySnapshot today;
}

enum SyncOutcome { created, replayed, rejected }

class SyncItem {
  const SyncItem({required this.key, required this.outcome, this.cause});
  final String key;
  final SyncOutcome outcome;

  /// Causa del rechazo (`TOO_OLD`, `NO_OPEN_SESSION`, ...).
  final String? cause;
}

class SyncResult {
  const SyncResult({required this.items, required this.today});
  final List<SyncItem> items;
  final TodaySnapshot? today;
}

/// Contrato con el servidor de Lapso (API v1, contrato 0.9.0).
///
/// Cada método indica la operación del contrato que usa. `HttpLapsoApi` es
/// la implementación real y `FakeLapsoApi` un servidor simulado en memoria
/// para demostraciones y pruebas.
///
/// Todos los métodos lanzan [LapsoException] si la operación falla.
abstract class LapsoApi {
  /// La última respuesta de [today], [captureSettings] o [restoreSession]
  /// salió de la copia guardada en el teléfono porque no hubo conexión.
  bool get servedFromCache;

  /// `getPublicTenant`. Devuelve `null` si la organización no existe.
  Future<Organization?> findOrganization(String slug);

  /// `resolveQr` con un QR de organización. `null` si el QR no es válido.
  Future<Organization?> resolveOrganizationQr(String token);

  /// `loginWithPin`.
  Future<Session> login({
    required String tenant,
    required String employeeNumber,
    required String pin,
  });

  /// `getMe` con la sesión guardada en el teléfono. `null` si no hay sesión
  /// o ya no es válida.
  Future<Session?> restoreSession();

  /// `changePin`.
  Future<void> changePin({required String currentPin, required String newPin});

  /// `logout`. Borra también la sesión guardada.
  Future<void> logout();

  /// `getMyToday`.
  Future<TodaySnapshot> today();

  /// `getMyCaptureSettings`.
  Future<CaptureSettings> captureSettings();

  /// `uploadEvidencePhoto`. Devuelve el `photo_id`.
  Future<String> uploadPhoto(Uint8List jpeg, {DateTime? capturedAt});

  /// `clockIn`, `clockOut`, `breakStart` o `breakEnd`, según el tipo.
  Future<RegisterResult> register(RegisterDraft draft);

  /// `syncOfflineEvents`. Hasta 50 registros, en el orden de captura.
  Future<SyncResult> sync(List<RegisterDraft> drafts);

  /// `getMyTimesheets`. El rango máximo es de 62 días.
  Future<List<DaySummary>> history({
    required DateTime from,
    required DateTime to,
  });

  /// `acceptConsent` o `revokeConsent`.
  Future<void> setConsent(
    Capability capability, {
    required bool accepted,
    int? noticeVersion,
  });

  /// `listMyEvidenceViews`.
  Future<List<EvidenceView>> evidenceViews();

  /// `listMyOfflineRejections`.
  Future<List<Rejection>> rejections();

  /// `getPublicLegalText`. [kind] es `AVISO_PRIVACIDAD`,
  /// `POLITICA_CONSERVACION` o `MEDIO_REGISTRO`. `null` si no hay texto.
  Future<LegalText?> legalText(String kind);

  /// `getMyEventPhoto`. `null` si la foto ya no existe.
  Future<Uint8List?> eventPhoto(String eventId);

  /// `getBranding`: el contacto de soporte de la organización.
  Future<SupportContact> supportContact();
}

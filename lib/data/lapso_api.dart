import '../domain/models.dart';

enum LoginStatus { ok, wrongCredentials, locked, noWorkerProfile }

class LoginResult {
  const LoginResult({
    required this.status,
    this.employee,
    this.mustChangePin = false,
    this.attemptsLeft,
    this.lockedUntil,
  });

  final LoginStatus status;
  final Employee? employee;

  /// El PIN es temporal y debe cambiarse antes de continuar.
  final bool mustChangePin;
  final int? attemptsLeft;
  final DateTime? lockedUntil;
}

class SyncResult {
  const SyncResult({required this.accepted, required this.rejected});
  final List<TimeEvent> accepted;
  final List<Rejection> rejected;
}

/// Error que la app muestra tal cual al usuario.
class LapsoException implements Exception {
  const LapsoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Contrato con el servidor de Lapso (API v1).
///
/// Cada método indica la operación real que la app 0.1.6 ya consume, para que
/// la implementación HTTP solo tenga que mapear una a una. Mientras no haya
/// acceso al backend, la app usa `FakeLapsoApi`.
abstract class LapsoApi {
  /// `GET /tenants/{slug}/public` y `GET /branding/current`
  Future<Organization?> findOrganization(String code);

  /// `POST /auth/pin`
  Future<LoginResult> login({
    required Organization organization,
    required String employeeNumber,
    required String pin,
    required DateTime now,
  });

  /// `POST /auth/pin/change`
  Future<void> changePin(String newPin);

  /// `POST /auth/logout`
  Future<void> logout();

  /// `GET /me/today` (centro, horario y qué evidencia pide)
  Future<WorkCenter> workCenter();

  /// `GET /me/timesheets`
  Future<List<TimeEvent>> history();

  /// `POST /time-events/clock-in`, `clock-out`, `break-start`, `break-end`
  /// y `POST /evidence/photos` cuando hay foto.
  Future<TimeEvent> register(TimeEvent draft);

  /// `POST /time-events/sync`
  Future<SyncResult> sync(List<TimeEvent> pending, {required DateTime now});

  /// `GET /me/consents`
  Future<Map<Capability, bool>> consents();

  /// `POST /me/consents` y `POST /me/consents/{capability}/revoke`
  Future<void> setConsent(Capability capability, {required bool accepted});

  /// `GET /me/evidence-views`
  Future<List<EvidenceView>> evidenceViews();

  /// `GET /me/offline/rejections`
  Future<List<Rejection>> rejections();
}

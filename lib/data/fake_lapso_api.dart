import '../domain/models.dart';
import '../domain/rules.dart';
import 'lapso_api.dart';

/// Servidor simulado en memoria. Permite recorrer toda la app sin backend.
///
/// Datos de prueba:
/// - Organización: `campo-prueba`
/// - Empleado: `GIL-001`
/// - PIN: `482913`. Con el PIN temporal `735194` la app obliga a cambiarlo.
class FakeLapsoApi implements LapsoApi {
  FakeLapsoApi({DateTime? seedNow}) {
    _seed(seedNow ?? DateTime.now());
  }

  static const Duration _latency = Duration(milliseconds: 350);

  static const Organization _org = Organization(
    slug: 'campo-prueba',
    name: 'Servicios Campo de Prueba',
  );
  static const Employee _employee = Employee(
    number: 'GIL-001',
    name: 'Gilberto Damián',
  );
  static const String _temporaryPin = '735194';

  String _pin = '482913';
  int _failed = 0;
  DateTime? _lockedUntil;
  int _seq = 1037;

  final List<TimeEvent> _events = <TimeEvent>[];
  final List<Rejection> _rejections = <Rejection>[];
  final List<EvidenceView> _views = <EvidenceView>[];
  final Map<Capability, bool> _consents = <Capability, bool>{
    Capability.ubicacion: true,
    Capability.foto: true,
  };

  static const Evidence _full = Evidence(
    qrRead: true,
    location: LocationResult.dentro,
    photoTaken: true,
  );

  void _seed(DateTime now) {
    final DateTime today = dayOf(now);
    DateTime at(int daysAgo, int h, int m) =>
        today.subtract(Duration(days: daysAgo)).add(Duration(hours: h, minutes: m));

    void add(EventType t, DateTime when, {PauseType? pause, Evidence? ev, bool offline = false}) {
      _seq += 1;
      _events.add(
        TimeEvent(
          id: 'seed-$_seq',
          type: t,
          at: when,
          pauseType: pause,
          seq: _seq,
          hash: _hashFor(_seq),
          offline: offline,
          evidence: ev ?? Evidence.none,
        ),
      );
    }

    // Anteayer: jornada completa.
    add(EventType.entrada, at(2, 9, 0), ev: _full);
    add(EventType.pausaInicio, at(2, 13, 30), pause: PauseType.comida);
    add(EventType.pausaFin, at(2, 14, 25));
    add(EventType.salida, at(2, 18, 10), ev: _full);
    // Ayer: jornada completa con un registro sin conexión.
    add(EventType.entrada, at(1, 9, 3), ev: _full);
    add(EventType.pausaInicio, at(1, 14, 0), pause: PauseType.comida);
    add(EventType.pausaFin, at(1, 15, 0), offline: true);
    add(
      EventType.salida,
      at(1, 18, 5),
      ev: const Evidence(
        qrRead: true,
        location: LocationResult.dentro,
        photoTaken: false,
      ),
    );

    _views
      ..add(
        EvidenceView(
          viewer: 'Ana Torres Pérez',
          what: Capability.ubicacion,
          eventLabel: 'tu entrada de ayer',
          reason: 'Revisión de una corrección',
          at: at(0, 9, 14),
        ),
      )
      ..add(
        EvidenceView(
          viewer: 'Recursos Humanos',
          what: Capability.foto,
          eventLabel: 'tu salida de anteayer',
          reason: 'Auditoría del periodo',
          at: at(1, 12, 40),
        ),
      );
  }

  /// Huella de 64 caracteres hexadecimales. Solo para la simulación.
  static String _hashFor(int seq) {
    int x = (seq * 2654435761) & 0xFFFFFFFF;
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < 8; i++) {
      x = (x * 1664525 + 1013904223) & 0xFFFFFFFF;
      out.write(x.toRadixString(16).padLeft(8, '0'));
    }
    return out.toString();
  }

  @override
  Future<Organization?> findOrganization(String code) async {
    await Future<void>.delayed(_latency);
    final String clean = code.trim().toLowerCase();
    if (clean == _org.slug || clean.endsWith('/${_org.slug}')) return _org;
    return null;
  }

  @override
  Future<LoginResult> login({
    required Organization organization,
    required String employeeNumber,
    required String pin,
    required DateTime now,
  }) async {
    await Future<void>.delayed(_latency);
    final DateTime? locked = _lockedUntil;
    if (locked != null) {
      if (now.isBefore(locked)) {
        return LoginResult(status: LoginStatus.locked, lockedUntil: locked);
      }
      _lockedUntil = null;
      _failed = 0;
    }
    final bool sameEmployee =
        employeeNumber.trim().toUpperCase() == _employee.number;
    if (sameEmployee && (pin == _pin || pin == _temporaryPin)) {
      _failed = 0;
      return LoginResult(
        status: LoginStatus.ok,
        employee: _employee,
        mustChangePin: pin == _temporaryPin,
      );
    }
    _failed += 1;
    if (_failed >= kMaxPinAttempts) {
      _lockedUntil = now.add(const Duration(minutes: kLockMinutes));
      return LoginResult(status: LoginStatus.locked, lockedUntil: _lockedUntil);
    }
    return LoginResult(
      status: LoginStatus.wrongCredentials,
      attemptsLeft: kMaxPinAttempts - _failed,
    );
  }

  @override
  Future<void> changePin(String newPin) async {
    await Future<void>.delayed(_latency);
    _pin = newPin;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(_latency);
  }

  @override
  Future<WorkCenter> workCenter() async {
    return const WorkCenter(
      name: 'Oficina Campo',
      startHour: 9,
      endHour: 18,
      mealMinutes: 60,
      requiresQr: true,
      requiresLocation: true,
      requiresPhoto: true,
    );
  }

  @override
  Future<List<TimeEvent>> history() async {
    await Future<void>.delayed(_latency);
    return List<TimeEvent>.of(_events);
  }

  @override
  Future<TimeEvent> register(TimeEvent draft) async {
    await Future<void>.delayed(_latency);
    _seq += 1;
    final TimeEvent accepted = draft.accepted(seq: _seq, hash: _hashFor(_seq));
    _events.add(accepted);
    return accepted;
  }

  @override
  Future<SyncResult> sync(
    List<TimeEvent> pending, {
    required DateTime now,
  }) async {
    await Future<void>.delayed(_latency);
    final List<TimeEvent> accepted = <TimeEvent>[];
    final List<Rejection> rejected = <Rejection>[];
    for (final TimeEvent e in pending) {
      if (e.at.isAfter(now.add(const Duration(minutes: 5)))) {
        final Rejection r = Rejection(
          event: e,
          reason:
              'La hora de tu teléfono estaba más adelantada de lo permitido. '
              'Corrige la hora del teléfono y solicita una corrección de ese registro.',
        );
        rejected.add(r);
        _rejections.add(r);
      } else {
        _seq += 1;
        final TimeEvent ok = e.accepted(seq: _seq, hash: _hashFor(_seq));
        _events.add(ok);
        accepted.add(ok);
      }
    }
    return SyncResult(accepted: accepted, rejected: rejected);
  }

  @override
  Future<Map<Capability, bool>> consents() async {
    return Map<Capability, bool>.of(_consents);
  }

  @override
  Future<void> setConsent(Capability capability, {required bool accepted}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _consents[capability] = accepted;
  }

  @override
  Future<List<EvidenceView>> evidenceViews() async {
    await Future<void>.delayed(_latency);
    return List<EvidenceView>.of(_views);
  }

  @override
  Future<List<Rejection>> rejections() async {
    return List<Rejection>.of(_rejections);
  }
}

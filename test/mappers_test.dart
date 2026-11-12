import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lapso_jornada/data/lapso_api.dart';
import 'package:lapso_jornada/data/mappers.dart';
import 'package:lapso_jornada/domain/models.dart';

/// Ejemplos tomados de `Lapso-Contrato/api/guia-api-app.md` (contrato 0.9.0).
const String _event = '''
{
  "id": "3f2c8a52-6a7e-4a43-9d8e-1c2b3a4d5e6f",
  "event_type": "CLOCK_IN",
  "occurred_at": "2026-10-13T14:01:05Z",
  "tz": "America/Mexico_City",
  "channel": "PWA",
  "work_center_id": "7a1c2b3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d",
  "break_type": null,
  "seq": 42,
  "hash": "9f3a1c0700000000000000000000000000000000000000000000000000000000",
  "effective_at": "2026-10-13T14:01:05Z",
  "offline": null,
  "verification": {
    "location": {"mode": "OPTIONAL", "status": "CAPTURADA", "zone": "DENTRO", "low_precision": false},
    "qr": {"mode": "OFF", "status": "NO_PRESENTADO"},
    "photo": {"mode": "OPTIONAL", "status": "CAPTURADA", "available": true},
    "required_missing": []
  }
}''';

const String _session = '''
{
  "id": "c0ffee00-1111-4222-8333-444455556666",
  "timezone": "America/Mexico_City",
  "business_date": "2026-10-13",
  "status": "OPEN",
  "work_center_name": "Oficina Campo",
  "started_at": "2026-10-13T14:01:05Z",
  "ended_at": null,
  "scheduled_end": "2026-10-13T23:00:00Z",
  "presence_seconds": null,
  "break_seconds": 0,
  "worked_seconds": null,
  "breaks": [],
  "events": [$_event],
  "corrected": false,
  "can_request_correction": false
}''';

const String _today = '''
{
  "date": "2026-10-13",
  "timezone": "America/Mexico_City",
  "server_time": "2026-10-13T14:01:06Z",
  "worker": {"id": "11111111-2222-4333-8444-555555555555", "employee_number": "e001", "full_name": "Laura Pérez"},
  "work_center_name": "Oficina Campo",
  "status": "OPEN",
  "allowed_actions": ["CLOCK_OUT", "BREAK_START"],
  "sessions": [$_session],
  "worked_seconds_today": 0,
  "break_seconds_today": 0,
  "scheduled_end": "2026-10-13T23:00:00Z",
  "has_incomplete_session": false,
  "last_event": $_event,
  "pending_corrections": 0
}''';

const String _capture = '''
{
  "work_center": {"id": "7a1c2b3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d", "name": "Oficina Campo", "timezone": "America/Mexico_City", "zone_configured": true},
  "server_time": "2026-10-13T14:01:06Z",
  "notice_version": 2,
  "capabilities": [
    {
      "capability": "LOCATION",
      "mode": "OPTIONAL",
      "event_types": ["CLOCK_IN", "CLOCK_OUT"],
      "active": true,
      "consent": {"capability": "LOCATION", "status": "ACCEPTED", "notice_version": 2, "required_notice_version": 2, "recorded_at": "2026-10-10T15:00:00Z"}
    },
    {"capability": "PHOTO", "mode": "OFF", "event_types": [], "active": false, "consent": null}
  ],
  "qr_rotation_seconds": 60,
  "offline": {"allowed": true, "max_age_hours": 24, "clock_tolerance_seconds": 120}
}''';

Json decode(String source) => asJson(jsonDecode(source))!;

void main() {
  final DateTime clockIn = DateTime.utc(2026, 10, 13, 14, 1, 5);

  test('evento con su evidencia', () {
    final TimeEvent event = eventOf(decode(_event))!;
    expect(event.type, EventType.entrada);
    expect(event.at.toUtc(), clockIn);
    expect(event.seq, 42);
    expect(event.pending, isFalse);
    expect(event.offline, isFalse);
    expect(event.evidence.qrRead, isNull);
    expect(event.evidence.location, LocationResult.dentro);
    expect(event.evidence.photoTaken, isTrue);
    expect(event.evidence.photoAvailable, isTrue);
    expect(event.evidence.complete, isTrue);
  });

  test('estados de evidencia que no se capturó', () {
    final Evidence evidence = evidenceOf(
      decode('''
{
  "location": {"mode": "REQUIRED", "status": "SIN_CONSENTIMIENTO", "zone": null, "low_precision": false},
  "qr": {"mode": "REQUIRED", "status": "NO_VERIFICADO"},
  "photo": {"mode": "OPTIONAL", "status": "FALLO_SUBIDA", "available": false},
  "required_missing": ["LOCATION", "QR"]
}'''),
    );
    expect(evidence.location, LocationResult.sinConsentimiento);
    expect(evidence.qrRead, isFalse);
    expect(evidence.photoTaken, isFalse);
    expect(evidence.requiredMissing, isTrue);
    expect(evidence.complete, isFalse);
  });

  test('getMyToday', () {
    final TodaySnapshot today = todayOf(decode(_today));
    expect(today.status, WorkStatus.enJornada);
    expect(
      today.allowedActions,
      <EventType>{EventType.salida, EventType.pausaInicio},
    );
    expect(today.events.length, 1);
    expect(today.sessionStart?.toUtc(), clockIn);
    expect(today.employee?.number, 'e001');
    expect(today.employee?.name, 'Laura Pérez');
    expect(today.workCenterName, 'Oficina Campo');
    expect(today.scheduledEnd?.toUtc(), DateTime.utc(2026, 10, 13, 23));
    expect(today.lastEvent?.seq, 42);
    expect(today.serverTime.toUtc(), DateTime.utc(2026, 10, 13, 14, 1, 6));
  });

  test('getMyCaptureSettings', () {
    final CaptureSettings settings = captureSettingsOf(decode(_capture));
    expect(settings.workCenterName, 'Oficina Campo');
    expect(settings.zoneConfigured, isTrue);
    expect(settings.noticeVersion, 2);
    expect(settings.location.mode, CaptureMode.optional);
    expect(settings.location.asks(EventType.entrada), isTrue);
    expect(settings.location.asks(EventType.pausaInicio), isFalse);
    expect(settings.location.active, isTrue);
    expect(settings.location.accepted, isTrue);
    expect(settings.photo.mode, CaptureMode.off);
    expect(settings.photo.asks(EventType.entrada), isFalse);
    expect(settings.photo.needsAnswer, isFalse);
    expect(settings.qr.mode, CaptureMode.off);
    expect(settings.offlineAllowed, isTrue);
    expect(settings.offlineMaxAgeHours, 24);
  });

  test('getMyTimesheets', () {
    final List<DaySummary> days = timesheetOf(
      decode('''
{
  "worker_id": "11111111-2222-4333-8444-555555555555",
  "from": "2026-10-12",
  "to": "2026-10-13",
  "days": [
    {"date": "2026-10-12", "sessions": [], "worked_seconds": 0, "break_seconds": 0},
    {"date": "2026-10-13", "sessions": [$_session], "worked_seconds": 0, "break_seconds": 0}
  ]
}'''),
    );
    expect(days.length, 2);
    expect(days.first.day, DateTime(2026, 10, 13));
    expect(days.first.status, WorkStatus.enJornada);
    expect(days.first.events.length, 1);
    expect(days.first.start?.toUtc(), clockIn);
    expect(days.first.end, isNull);
    expect(days.last.hasRecords, isFalse);
    expect(days.last.status, WorkStatus.sinEntrada);
  });

  test('lo que la app manda al registrar', () {
    final RegisterDraft draft = RegisterDraft(
      key: '01010101-0202-4303-8404-050505050505',
      type: EventType.pausaInicio,
      pauseType: PauseType.comida,
      declaredAt: DateTime.utc(2026, 10, 13, 18),
      qr: const QrReading(
        token: 'AbCdEfGhIjKlMnOp',
        rotatingCode: 'QRSTUVWXYZ012345',
      ),
      location: LocationReading.coordinates(
        lat: 19.43261,
        lon: -99.13321,
        accuracyMeters: 12.5,
        capturedAt: DateTime.utc(2026, 10, 13, 17, 59, 58),
      ),
      photoStatus: 'DENEGADO',
    );

    final Json body = clockBody(draft);
    expect(body['break_type'], 'MEAL');
    expect(body['qr_token'], 'AbCdEfGhIjKlMnOp');
    expect(body['qr_rotating_code'], 'QRSTUVWXYZ012345');
    expect(body['client_time'], '2026-10-13T18:00:00.000Z');
    expect(body['channel'], 'APP');
    final Json verification = asJson(body['verification'])!;
    expect(asJson(verification['location'])!['lat'], 19.43261);
    expect(asJson(verification['location'])!['accuracy_m'], 12.5);
    expect(asJson(verification['photo'])!['status'], 'DENEGADO');
    expect(clockPath(EventType.pausaInicio), '/time-events/break-start');

    final Json offline = offlineEventBody(draft);
    expect(offline['idempotency_key'], draft.key);
    expect(offline['event_type'], 'BREAK_START');
    expect(offline['client_declared_at'], '2026-10-13T18:00:00.000Z');
  });

  test('un registro pendiente sobrevive a guardarse y leerse', () {
    final RegisterDraft draft = RegisterDraft(
      key: '06060606-0707-4808-8909-0a0a0a0a0a0a',
      type: EventType.entrada,
      declaredAt: DateTime.utc(2026, 10, 13, 14),
      location: const LocationReading.unavailable('DENEGADO'),
      photoStatus: 'NO_DISPONIBLE',
      monotonicMs: 30000,
      monotonicSession: '0d0d0d0d-1e1e-4f1f-8a2a-3b3b3b3b3b3b',
      evidence: const Evidence(
        qrRead: false,
        location: LocationResult.sinPermiso,
        photoTaken: false,
      ),
    );
    final Json stored = decode(jsonEncode(draftToStore(draft)));
    final RegisterDraft restored = draftFromStore(stored)!;
    expect(restored.key, draft.key);
    expect(restored.type, EventType.entrada);
    expect(restored.declaredAt.toUtc(), draft.declaredAt);
    expect(restored.location?.status, 'DENEGADO');
    expect(restored.photoStatus, 'NO_DISPONIBLE');
    expect(restored.monotonicMs, 30000);
    expect(restored.evidence.qrRead, isFalse);
    expect(restored.evidence.location, LocationResult.sinPermiso);
    expect(restored.toPendingEvent().pending, isTrue);
  });

  test('syncOfflineEvents: resultado por evento', () {
    final SyncResult result = syncResultOf(
      decode('''
{
  "results": [
    {"idempotency_key": "01010101-0202-4303-8404-050505050505", "outcome": "CREATED", "event": $_event, "rejection": null},
    {"idempotency_key": "06060606-0707-4808-8909-0a0a0a0a0a0a", "outcome": "REJECTED", "event": null,
     "rejection": {"code": "OFFLINE_CONFLICT", "cause": "NO_OPEN_SESSION", "detail": "No había una jornada abierta."}}
  ],
  "today": $_today
}'''),
    );
    expect(result.items.length, 2);
    expect(result.items.first.outcome, SyncOutcome.created);
    expect(result.items.last.outcome, SyncOutcome.rejected);
    expect(result.items.last.cause, 'NO_OPEN_SESSION');
    expect(result.today?.status, WorkStatus.enJornada);
  });

  test('sesión, consultas de evidencia y rechazos', () {
    final Session session = sessionOf(
      decode('''
{
  "user_id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
  "display_name": "Laura Pérez",
  "roles": ["WORKER"],
  "worker_id": "11111111-2222-4333-8444-555555555555",
  "must_change_pin": true,
  "unread_notices": 2,
  "tenant": {"slug": "org-demo", "display_name": "Organización Demo", "logo_url": null, "primary_color": "#1F3A74", "secondary_color": "#4A7BE0"}
}'''),
    );
    expect(session.displayName, 'Laura Pérez');
    expect(session.mustChangePin, isTrue);
    expect(session.isWorker, isTrue);
    expect(session.organization.slug, 'org-demo');

    final List<EvidenceView> views = evidenceViewsOf(
      decode('''
{"items": [{"id": "abababab-cdcd-4efe-8f01-234567890abc", "viewed_at": "2026-10-13T16:00:00Z", "kind": "PHOTO",
  "event_id": "3f2c8a52-6a7e-4a43-9d8e-1c2b3a4d5e6f", "viewer_role": "HR", "viewer_name": "Ana Gómez"}], "next_cursor": null}'''),
    );
    expect(views.single.viewerName, 'Ana Gómez');
    expect(views.single.what, Capability.foto);

    final List<Rejection> rejections = rejectionsOf(
      decode('''
{"items": [{"id": "0b0b0b0b-0c0c-4d0d-8e0e-0f0f0f0f0f0f", "event_type": "CLOCK_OUT", "break_type": null,
  "client_declared_at": "2026-10-12T22:00:00Z", "received_at": "2026-10-14T01:00:00Z",
  "code": "OFFLINE_TOO_OLD", "cause": "TOO_OLD"}], "next_cursor": null}'''),
    );
    expect(rejections.single.event.type, EventType.salida);
    expect(rejections.single.reason, isNotEmpty);
  });
}

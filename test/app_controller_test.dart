import 'package:flutter_test/flutter_test.dart';
import 'package:lapso_jornada/data/fake_lapso_api.dart';
import 'package:lapso_jornada/data/key_value_store.dart';
import 'package:lapso_jornada/data/lapso_api.dart';
import 'package:lapso_jornada/domain/models.dart';
import 'package:lapso_jornada/platform/device_capture.dart';
import 'package:lapso_jornada/state/app_controller.dart';

AppController newController({KeyValueStore? store}) {
  final AppController c = AppController(
    api: FakeLapsoApi(),
    device: FakeDeviceCapture(),
    store: store,
    demoTools: true,
  );
  addTearDown(c.dispose);
  return c;
}

Future<AppController> signedIn({KeyValueStore? store}) async {
  final AppController c = newController(store: store);
  await c.start();
  expect(await c.chooseOrganization('campo-prueba'), isNull);
  final LoginResult r = await c.login('gil-001', '482913');
  expect(r.status, LoginStatus.ok);
  return c;
}

void main() {
  test('al arrancar sin nada guardado queda en la pantalla de acceso', () async {
    final AppController c = newController();
    expect(c.ready, isFalse);
    await c.start();
    expect(c.ready, isTrue);
    expect(c.hasOrganization, isFalse);
    expect(c.loggedIn, isFalse);
  });

  test('una organización desconocida devuelve un mensaje', () async {
    final AppController c = newController();
    expect(await c.chooseOrganization('no-existe'), isNotNull);
    expect(await c.chooseOrganization('con espacios'), isNotNull);
    expect(c.hasOrganization, isFalse);
  });

  test('la organización elegida se recuerda en el teléfono', () async {
    final MemoryStore store = MemoryStore();
    final AppController first = newController(store: store);
    await first.start();
    expect(await first.chooseOrganization('campo-prueba'), isNull);

    final AppController second = newController(store: store);
    await second.start();
    expect(second.organization?.slug, 'campo-prueba');
    expect(second.organization?.name, 'Servicios Campo de Prueba');
  });

  test('el quinto PIN incorrecto bloquea la cuenta', () async {
    final AppController c = newController();
    await c.chooseOrganization('campo-prueba');

    for (int i = 0; i < 4; i++) {
      final LoginResult wrong = await c.login('GIL-001', '000000');
      expect(wrong.status, LoginStatus.wrongCredentials);
    }
    final LoginResult fifth = await c.login('GIL-001', '000000');
    expect(fifth.status, LoginStatus.locked);
    expect(c.isLocked, isTrue);
    expect(c.loggedIn, isFalse);

    final LoginResult right = await c.login('GIL-001', '482913');
    expect(right.status, LoginStatus.locked);
  });

  test('el PIN temporal obliga a cambiarlo', () async {
    final AppController c = newController();
    await c.chooseOrganization('campo-prueba');
    await c.login('GIL-001', '735194');
    expect(c.loggedIn, isTrue);
    expect(c.mustChangePin, isTrue);
    expect(c.needsCurrentPin, isFalse);

    expect(await c.changePin('735194'), isNotNull);
    expect(await c.changePin('123456'), isNotNull);
    expect(await c.changePin('608417'), isNull);
    expect(c.mustChangePin, isFalse);
    expect(c.status, WorkStatus.sinEntrada);
  });

  test('cambiar el PIN con el actual equivocado lo dice', () async {
    final AppController c = await signedIn();
    expect(
      await c.changePin('608417', currentPin: '111222'),
      AppController.wrongCurrentPin,
    );
    expect(await c.changePin('608417', currentPin: '482913'), isNull);
  });

  test('una jornada completa: entrada, pausa, reanudación y salida', () async {
    final AppController c = await signedIn();
    expect(c.status, WorkStatus.sinEntrada);
    expect(c.allowedActions, <EventType>{EventType.entrada});
    expect(c.employee?.name, 'Gilberto Damián');
    expect(c.centerName, 'Oficina Campo');

    final TimeEvent entry = await c.register(EventType.entrada);
    expect(entry.pending, isFalse);
    expect(entry.seq, isNotNull);
    expect(entry.hash, isNotNull);
    expect(c.status, WorkStatus.enJornada);

    await expectLater(
      c.register(EventType.entrada),
      throwsA(isA<LapsoException>()),
    );
    await expectLater(
      c.register(EventType.pausaInicio),
      throwsA(isA<LapsoException>()),
    );

    await c.register(EventType.pausaInicio, pauseType: PauseType.comida);
    expect(c.status, WorkStatus.enPausa);
    expect(c.allowedActions.contains(EventType.salida), isTrue);

    await c.register(EventType.pausaFin);
    expect(c.status, WorkStatus.enJornada);

    await c.register(EventType.salida);
    expect(c.status, WorkStatus.terminada);
    expect(c.shift.length, 4);
  });

  test('la salida durante una pausa cierra la jornada', () async {
    final AppController c = await signedIn();
    await c.register(EventType.entrada);
    await c.register(EventType.pausaInicio, pauseType: PauseType.personal);
    await c.register(EventType.salida);
    expect(c.status, WorkStatus.terminada);
  });

  test('la evidencia aceptada viaja con el registro', () async {
    final AppController c = await signedIn();
    expect(c.consent(Capability.ubicacion), isTrue);
    expect(c.consent(Capability.foto), isFalse);
    expect(c.capture.photo.needsAnswer, isTrue);

    await c.setConsent(Capability.foto, accepted: true);
    expect(c.consent(Capability.foto), isTrue);

    final FakeDeviceCapture device = c.device as FakeDeviceCapture;
    final TimeEvent entry = await c.register(
      EventType.entrada,
      qr: const QrReading(token: 'DEMOqrTOKEN123456'),
      location: await device.readLocation(),
      photo: await device.takePhoto(),
    );
    expect(entry.evidence.qrRead, isTrue);
    expect(entry.evidence.location, LocationResult.dentro);
    expect(entry.evidence.photoTaken, isTrue);
    expect(entry.evidence.complete, isTrue);
  });

  test('sin consentimiento la ubicación no se manda', () async {
    final AppController c = await signedIn();
    await c.setConsent(Capability.ubicacion, accepted: false);
    expect(c.consent(Capability.ubicacion), isFalse);
    expect(c.capture.location.active, isFalse);

    final FakeDeviceCapture device = c.device as FakeDeviceCapture;
    final TimeEvent entry = await c.register(
      EventType.entrada,
      location: await device.readLocation(),
    );
    expect(entry.evidence.location, LocationResult.sinConsentimiento);
  });

  test('sin conexión el registro queda pendiente y luego se envía', () async {
    final MemoryStore store = MemoryStore();
    final AppController c = await signedIn(store: store);
    final FakeLapsoApi api = c.api as FakeLapsoApi;
    api.offline = true;

    final TimeEvent entry = await c.register(EventType.entrada);
    expect(entry.pending, isTrue);
    expect(c.offline, isTrue);
    expect(c.pending.length, 1);
    expect(c.status, WorkStatus.enJornada);
    expect(c.allowedActions.contains(EventType.salida), isTrue);
    await expectLater(c.syncPending(), throwsA(isA<LapsoException>()));
    expect(c.pending.length, 1);

    api.offline = false;
    expect(await c.syncPending(), 1);
    expect(c.pending, isEmpty);
    expect(c.rejections, isEmpty);
    expect(c.offline, isFalse);
    expect(c.status, WorkStatus.enJornada);
    expect(c.shift.single.pending, isFalse);
    expect(c.shift.single.offline, isTrue);
  });

  test('un registro con el reloj adelantado se rechaza al enviar', () async {
    final AppController c = await signedIn();
    final FakeLapsoApi api = c.api as FakeLapsoApi;
    api.offline = true;
    c.setPhoneClockAhead(true);
    await c.register(EventType.entrada);

    c.setPhoneClockAhead(false);
    api.offline = false;
    expect(await c.syncPending(), 0);
    expect(c.pending, isEmpty);
    expect(c.rejections.length, 1);
    expect(c.status, WorkStatus.sinEntrada);
  });

  test('una jornada de más de 16 horas dispara el aviso', () async {
    final AppController c = await signedIn();
    final FakeLapsoApi api = c.api as FakeLapsoApi;
    await c.register(EventType.entrada);
    expect(c.shouldWarnLongSession, isFalse);

    c.advanceClock(const Duration(hours: 17));
    await c.refresh();
    expect(api.clockOffset, const Duration(hours: 17));
    expect(c.shouldWarnLongSession, isTrue);

    await c.register(EventType.entrada, forceNewEntry: true);
    expect(c.shouldWarnLongSession, isFalse);
    expect(c.shift.length, 1);
  });

  test('el historial trae los días con sus números', () async {
    final AppController c = await signedIn();
    await c.reloadHistory();
    expect(c.historyLoaded, isTrue);
    expect(c.days.length, 62);

    final DateTime now = c.now;
    final DaySummary? yesterday =
        c.dayAt(DateTime(now.year, now.month, now.day - 1));
    expect(yesterday, isNotNull);
    expect(yesterday!.events.length, 4);
    expect(yesterday.status, WorkStatus.terminada);
    expect(yesterday.worked, const Duration(hours: 8, minutes: 12));
    expect(c.photoEvents.length, 4);
  });

  test('cerrar sesión limpia la sesión y conserva la organización', () async {
    final AppController c = await signedIn();
    await c.register(EventType.entrada);
    await c.logout();
    expect(c.loggedIn, isFalse);
    expect(c.hasOrganization, isTrue);
    expect(c.shift, isEmpty);
    expect(c.status, WorkStatus.sinEntrada);
  });
}

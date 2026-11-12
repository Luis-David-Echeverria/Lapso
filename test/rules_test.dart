import 'package:flutter_test/flutter_test.dart';
import 'package:lapso_jornada/domain/models.dart';
import 'package:lapso_jornada/domain/rules.dart';

TimeEvent ev(EventType type, DateTime at, {PauseType? pause}) {
  return TimeEvent(
    id: '${type.name}-${at.toIso8601String()}',
    type: type,
    at: at,
    pauseType: pause,
    seq: 1,
    hash: 'x',
  );
}

void main() {
  final DateTime day = DateTime(2026, 11, 10);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 10, h, m);

  final List<TimeEvent> fullDay = <TimeEvent>[
    ev(EventType.entrada, at(9)),
    ev(EventType.pausaInicio, at(13), pause: PauseType.comida),
    ev(EventType.pausaFin, at(14)),
    ev(EventType.salida, at(18)),
  ];

  group('estado de la jornada', () {
    test('sin registros no hay entrada', () {
      expect(statusOf(const <TimeEvent>[]), WorkStatus.sinEntrada);
    });

    test('sigue el último registro', () {
      expect(statusOf(fullDay.sublist(0, 1)), WorkStatus.enJornada);
      expect(statusOf(fullDay.sublist(0, 2)), WorkStatus.enPausa);
      expect(statusOf(fullDay.sublist(0, 3)), WorkStatus.enJornada);
      expect(statusOf(fullDay), WorkStatus.terminada);
    });

    test('la jornada vigente empieza en la última entrada', () {
      final List<TimeEvent> two = <TimeEvent>[
        ...fullDay,
        ev(EventType.entrada, DateTime(2026, 11, 11, 9)),
      ];
      expect(currentShift(two).length, 1);
      expect(currentShift(two).first.at, DateTime(2026, 11, 11, 9));
    });
  });

  group('tiempos', () {
    test('lo trabajado es la presencia menos las pausas', () {
      expect(workedOf(fullDay, at(20)), const Duration(hours: 8));
      expect(pausesOf(fullDay, at(20)), const Duration(hours: 1));
    });

    test('una pausa abierta cuenta hasta ahora', () {
      final List<TimeEvent> open = fullDay.sublist(0, 2);
      expect(pausesOf(open, at(13, 30)), const Duration(minutes: 30));
      expect(workedOf(open, at(13, 30)), const Duration(hours: 4));
      expect(openPause(open)?.pauseType, PauseType.comida);
    });

    test('una jornada en curso cuenta hasta ahora', () {
      expect(
        workedOf(fullDay.sublist(0, 1), at(11, 15)),
        const Duration(hours: 2, minutes: 15),
      );
    });
  });

  group('qué se puede registrar', () {
    test('entrada solo sin jornada abierta', () {
      expect(validateNext(WorkStatus.sinEntrada, EventType.entrada), isNull);
      expect(validateNext(WorkStatus.terminada, EventType.entrada), isNull);
      expect(validateNext(WorkStatus.enJornada, EventType.entrada), isNotNull);
      expect(validateNext(WorkStatus.enPausa, EventType.entrada), isNotNull);
    });

    test('salida con jornada abierta, también durante una pausa', () {
      expect(validateNext(WorkStatus.enJornada, EventType.salida), isNull);
      expect(validateNext(WorkStatus.enPausa, EventType.salida), isNull);
      expect(validateNext(WorkStatus.sinEntrada, EventType.salida), isNotNull);
      expect(validateNext(WorkStatus.terminada, EventType.salida), isNotNull);
    });

    test('acciones posibles por estado', () {
      expect(
        actionsFor(WorkStatus.sinEntrada),
        <EventType>{EventType.entrada},
      );
      expect(
        actionsFor(WorkStatus.enJornada),
        <EventType>{EventType.salida, EventType.pausaInicio},
      );
      expect(
        actionsFor(WorkStatus.enPausa),
        <EventType>{EventType.salida, EventType.pausaFin},
      );
      expect(applyEvent(WorkStatus.enPausa, EventType.salida),
          WorkStatus.terminada);
    });

    test('pausas', () {
      expect(validateNext(WorkStatus.enJornada, EventType.pausaInicio), isNull);
      expect(
        validateNext(WorkStatus.enPausa, EventType.pausaInicio),
        isNotNull,
      );
      expect(validateNext(WorkStatus.enPausa, EventType.pausaFin), isNull);
      expect(validateNext(WorkStatus.enJornada, EventType.pausaFin), isNotNull);
    });
  });

  group('jornada larga', () {
    final List<TimeEvent> open = <TimeEvent>[ev(EventType.entrada, at(9))];

    test('avisa a partir de 16 horas abierta', () {
      expect(isLongSession(open, DateTime(2026, 11, 11, 0, 59)), isFalse);
      expect(isLongSession(open, DateTime(2026, 11, 11, 1)), isTrue);
    });

    test('no avisa si ya hay salida', () {
      expect(isLongSession(fullDay, DateTime(2026, 11, 12)), isFalse);
    });
  });

  group('PIN nuevo', () {
    String? check(String pin, {String? current}) =>
        validateNewPin(pin, employeeNumber: 'GIL-001', currentPin: current);

    test('acepta un PIN válido', () {
      expect(check('482913'), isNull);
    });

    test('rechaza longitudes y caracteres inválidos', () {
      expect(check('12345'), isNotNull);
      expect(check('1234567'), isNotNull);
      expect(check('12a456'), isNotNull);
    });

    test('rechaza iguales, secuencias y grupos repetidos', () {
      expect(check('111111'), isNotNull);
      expect(check('123456'), isNotNull);
      expect(check('654321'), isNotNull);
      expect(check('121212'), isNotNull);
      expect(check('123123'), isNotNull);
    });

    test('rechaza el número de empleado', () {
      expect(check('000001'), isNotNull);
      expect(
        validateNewPin('901234', employeeNumber: 'EMP-1234'),
        isNotNull,
      );
    });

    test('rechaza el PIN actual', () {
      expect(check('482913', current: '482913'), isNotNull);
      expect(check('482913', current: '735194'), isNull);
    });
  });

  group('resumen del día', () {
    test('jornada completa', () {
      final DaySummary s = summarizeDay(day, fullDay, DateTime(2026, 11, 12));
      expect(s.status, WorkStatus.terminada);
      expect(s.worked, const Duration(hours: 8));
      expect(s.pauses, const Duration(hours: 1));
      expect(s.presence, const Duration(hours: 9));
      expect(s.incomplete, isFalse);
      expect(s.start, at(9));
      expect(s.end, at(18));
    });

    test('día sin registros', () {
      final DaySummary s = summarizeDay(
        DateTime(2026, 11, 9),
        fullDay,
        DateTime(2026, 11, 12),
      );
      expect(s.events, isEmpty);
      expect(s.hasRecords, isFalse);
      expect(s.status, WorkStatus.sinEntrada);
      expect(s.worked, Duration.zero);
    });

    test('día anterior sin salida queda incompleto', () {
      final DaySummary s = summarizeDay(
        day,
        fullDay.sublist(0, 3),
        DateTime(2026, 11, 12),
      );
      expect(s.incomplete, isTrue);
      expect(s.end, isNull);
      expect(s.worked, const Duration(hours: 4));
    });
  });

  group('códigos QR y de organización', () {
    test('QR con dirección, token y código cambiante', () {
      final QrReading? qr = parseQrPayload(
        'https://validacion.lapsojornada.mx/q/AbCdEfGhIjKlMnOp'
        '?k=QRSTUVWXYZ012345',
      );
      expect(qr?.token, 'AbCdEfGhIjKlMnOp');
      expect(qr?.rotatingCode, 'QRSTUVWXYZ012345');
    });

    test('QR con el token solo', () {
      final QrReading? qr = parseQrPayload('AbCdEfGhIjKlMnOp');
      expect(qr?.token, 'AbCdEfGhIjKlMnOp');
      expect(qr?.rotatingCode, isNull);
    });

    test('lo que no es un QR de Lapso se descarta', () {
      expect(parseQrPayload(''), isNull);
      expect(parseQrPayload('hola'), isNull);
      expect(parseQrPayload('https://ejemplo.mx/'), isNull);
    });

    test('código de organización escrito o pegado como enlace', () {
      expect(parseOrganizationCode(' Campo-Prueba '), 'campo-prueba');
      expect(
        parseOrganizationCode('https://lapsojornada.mx/o/campo-prueba'),
        'campo-prueba',
      );
      expect(
        parseOrganizationCode('https://lapsojornada.mx/?tenant=org-demo'),
        'org-demo',
      );
      expect(parseOrganizationCode('con espacios'), isNull);
      expect(parseOrganizationCode(''), isNull);
    });
  });
}

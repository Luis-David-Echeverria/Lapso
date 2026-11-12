import 'package:flutter/material.dart';

import '../../data/lapso_api.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../platform/device_capture.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'comprobante_screen.dart';
import 'consentimiento_screen.dart';
import 'escaner_qr_screen.dart';
import 'evidencia_screen.dart';

/// Capturas por las que ya se preguntó desde que se abrió la app, para no
/// insistir en cada registro a quien respondió «Ahora no».
final Set<Capability> _askedThisRun = <Capability>{};

/// Flujo completo de un registro:
/// aceptación de capturas → QR del centro → ubicación y foto → envío →
/// comprobante.
///
/// Cada paso aparece solo si el centro pide esa captura para ese tipo de
/// registro (`getMyCaptureSettings`). Si algo falla o la persona no acepta,
/// el registro sigue adelante y queda marcado.
///
/// Con [forceNewEntry] se registra una entrada aunque haya una jornada
/// abierta de más de 16 horas.
Future<void> startRegisterFlow(
  BuildContext context,
  EventType type, {
  PauseType? pauseType,
  bool forceNewEntry = false,
}) async {
  final NavigatorState nav = Navigator.of(context);
  final AppController c = AppScope.read(context);

  // 1. Antes de capturar datos personales se pide la aceptación.
  for (final Capability capability in Capability.values) {
    final CaptureRule rule = c.capture.rule(capability);
    if (!rule.asks(type) || !rule.needsAnswer) continue;
    if (!_askedThisRun.add(capability)) continue;
    final bool? answer = await nav.push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            ConsentimientoScreen(capability: capability),
      ),
    );
    if (answer == null) {
      _askedThisRun.remove(capability);
      return;
    }
  }

  final CaptureSettings settings = c.capture;
  final bool qrAsked = settings.qr.asks(type);

  // 2. QR del centro.
  QrReading? qr;
  if (qrAsked) {
    final String center = c.centerName;
    final String? payload = await nav.push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => EscanerQrScreen(
          title: registerTitle(type),
          heading: 'Escanea el código QR de tu centro',
          hint: center.isEmpty
              ? 'Es el código de tu centro de trabajo.'
              : 'Es el código de tu centro de trabajo: $center.',
          allowSkip: true,
        ),
      ),
    );
    if (payload == null) return;
    qr = parseQrPayload(payload);
  }

  // 3. Ubicación y foto.
  LocationReading? location;
  PhotoCapture? photo;
  if (settings.location.asks(type) || settings.photo.asks(type)) {
    final EvidenceResult? evidence = await nav.push<EvidenceResult>(
      MaterialPageRoute<EvidenceResult>(
        builder: (BuildContext context) =>
            EvidenciaScreen(type: type, qrAsked: qrAsked, qr: qr),
      ),
    );
    if (evidence == null) return;
    location = evidence.location;
    photo = evidence.photo;
  }

  // 4. Envío y comprobante.
  await nav.push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => _SendingScreen(
        type: type,
        pauseType: pauseType,
        qr: qr,
        location: location,
        photo: photo,
        forceNewEntry: forceNewEntry,
      ),
    ),
  );
}

/// Envía el registro. Una entrada o una salida terminan en el comprobante;
/// una pausa o una reanudación, de vuelta en Mi jornada con un aviso.
class _SendingScreen extends StatefulWidget {
  const _SendingScreen({
    required this.type,
    required this.pauseType,
    required this.qr,
    required this.location,
    required this.photo,
    required this.forceNewEntry,
  });

  final EventType type;
  final PauseType? pauseType;
  final QrReading? qr;
  final LocationReading? location;
  final PhotoCapture? photo;
  final bool forceNewEntry;

  @override
  State<_SendingScreen> createState() => _SendingScreenState();
}

class _SendingScreenState extends State<_SendingScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _send();
  }

  Future<void> _send() async {
    final AppController c = AppScope.read(context);
    final EventType type = widget.type;
    try {
      final TimeEvent event = await c.register(
        type,
        pauseType: widget.pauseType,
        qr: widget.qr,
        location: widget.location,
        photo: widget.photo,
        forceNewEntry: widget.forceNewEntry,
      );
      if (!mounted) return;
      if (type == EventType.entrada || type == EventType.salida) {
        await Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (BuildContext context) =>
                ComprobanteScreen(event: event, fresh: true),
          ),
        );
        return;
      }
      final String what =
          type == EventType.pausaInicio ? 'Pausa iniciada' : 'Jornada reanudada';
      showLapsoSnack(
        context,
        event.pending
            ? '$what a las ${hhmm(event.at)}. Guardada en tu teléfono.'
            : '$what a las ${hhmm(event.at)}.',
      );
      Navigator.of(context).pop();
    } on LapsoException catch (e) {
      if (!mounted) return;
      showLapsoSnack(context, e.message);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: LapsoColors.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Guardando tu registro…',
                  style: LapsoText.heading(20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

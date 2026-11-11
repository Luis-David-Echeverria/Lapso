import 'package:flutter/material.dart';

import '../../data/lapso_api.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import 'comprobante_screen.dart';
import 'escaner_qr_screen.dart';
import 'evidencia_screen.dart';

/// Flujo completo para registrar una entrada o una salida:
/// QR del centro → ubicación y foto → envío → comprobante.
///
/// Cada paso de evidencia solo aparece si el centro lo pide. Si alguno
/// falla, el usuario puede registrar sin él y el registro queda marcado.
///
/// Con [forceNewEntry] se registra una entrada aunque haya una jornada
/// abierta (caso de jornada de más de 16 horas que quedó sin salida).
Future<void> startRegisterFlow(
  BuildContext context,
  EventType type, {
  bool forceNewEntry = false,
}) async {
  final NavigatorState nav = Navigator.of(context);
  final AppController c = AppScope.read(context);
  final WorkCenter? center = c.center;

  Evidence evidence = Evidence.none;
  if (center != null) {
    bool? qr;
    if (center.requiresQr) {
      qr = await nav.push<bool>(
        MaterialPageRoute<bool>(
          builder: (BuildContext context) => EscanerQrScreen(
            title: registerTitle(type),
            heading: 'Escanea el código QR de tu centro',
            hint: 'Es el código de tu centro de trabajo: ${center.name}.',
            allowSkip: true,
          ),
        ),
      );
      if (qr == null) return;
    }
    if (center.requiresLocation || center.requiresPhoto) {
      final Evidence? gathered = await nav.push<Evidence>(
        MaterialPageRoute<Evidence>(
          builder: (BuildContext context) => EvidenciaScreen(
            type: type,
            center: center,
            qrRead: qr,
          ),
        ),
      );
      if (gathered == null) return;
      evidence = gathered;
    } else {
      evidence = Evidence(qrRead: qr);
    }
  }

  await nav.push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => _SendingScreen(
        type: type,
        evidence: evidence,
        forceNewEntry: forceNewEntry,
      ),
    ),
  );
}

/// Envía el registro y se reemplaza por el comprobante.
class _SendingScreen extends StatefulWidget {
  const _SendingScreen({
    required this.type,
    required this.evidence,
    required this.forceNewEntry,
  });

  final EventType type;
  final Evidence evidence;
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
    try {
      final TimeEvent event = await c.register(
        widget.type,
        evidence: widget.evidence,
        forceNewEntry: widget.forceNewEntry,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              ComprobanteScreen(event: event, fresh: true),
        ),
      );
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

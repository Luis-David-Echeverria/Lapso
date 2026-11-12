import 'package:flutter/material.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Comprobante de un registro: hora, centro, evidencia, número de evento y
/// huella. Con [fresh] es la confirmación que cierra el flujo de registro.
class ComprobanteScreen extends StatelessWidget {
  const ComprobanteScreen({super.key, required this.event, this.fresh = false});

  final TimeEvent event;

  /// El registro se acaba de hacer.
  final bool fresh;

  String get _heading {
    if (event.pending) {
      switch (event.type) {
        case EventType.entrada:
          return 'Entrada guardada en tu teléfono';
        case EventType.salida:
          return 'Salida guardada en tu teléfono';
        case EventType.pausaInicio:
          return 'Pausa guardada en tu teléfono';
        case EventType.pausaFin:
          return 'Reanudación guardada en tu teléfono';
      }
    }
    switch (event.type) {
      case EventType.entrada:
        return 'Entrada registrada';
      case EventType.salida:
        return 'Salida registrada';
      case EventType.pausaInicio:
        return 'Pausa iniciada';
      case EventType.pausaFin:
        return 'Jornada reanudada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final bool pending = event.pending;
    final String evidence = evidenceSummary(event.evidence);
    final PauseType? pause = event.pauseType;
    final int? seq = event.seq;
    final String? hash = event.hash;
    final bool complete = event.evidence.complete &&
        event.evidence.location != LocationResult.fuera;
    final String center = c.centerName;

    return PopScope(
      canPop: !fresh,
      child: Scaffold(
        backgroundColor: LapsoColors.surface,
        appBar: fresh ? null : AppBar(title: const Text('Comprobante')),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, fresh ? 40 : 12, 24, 16),
                  child: Column(
                    children: <Widget>[
                      StateBadge(
                        icon: pending ? Icons.cloud_off_outlined : Icons.check,
                        tone: pending ? Tone.warn : Tone.good,
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        liveRegion: fresh,
                        child: Text(
                          _heading,
                          textAlign: TextAlign.center,
                          style: LapsoText.heading(24),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hhmm(event.at),
                        style: LapsoText.heading(52).copyWith(height: 1.1),
                      ),
                      Text(longDate(event.at), style: LapsoText.secondary),
                      const SizedBox(height: 20),
                      LapsoCard(
                        child: DividedColumn(
                          children: <Widget>[
                            if (pause != null)
                              InfoRow(
                                label: 'Tipo de pausa',
                                value: pauseLabel(pause),
                              ),
                            if (center.isNotEmpty)
                              InfoRow(label: 'Centro', value: center),
                            if (evidence.isNotEmpty)
                              InfoRow(
                                label: 'Evidencia',
                                value: evidence,
                                valueColor: complete
                                    ? LapsoColors.navy
                                    : LapsoColors.warnText,
                              ),
                            if (event.offline)
                              InfoRow(
                                label: 'Hora',
                                value: event.clockSuspect
                                    ? 'La de tu teléfono (reloj por revisar)'
                                    : 'Declarada por tu teléfono',
                              ),
                            InfoRow(
                              label: 'Evento',
                              value: seq == null ? 'Por asignar' : 'N.º $seq',
                            ),
                            if (hash != null)
                              InfoRow(
                                label: 'Huella',
                                value: shortHash(hash),
                                mono: true,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (pending)
                        const NoticeBanner(
                          tone: Tone.warn,
                          icon: Icons.cloud_off_outlined,
                          text: 'No hay conexión. Tu registro está guardado '
                              'en este teléfono y se enviará solo al '
                              'reconectar. No cierres sesión antes.',
                        )
                      else
                        const NoticeBanner(
                          text: 'El número de evento y la huella prueban que '
                              'tu registro existe y no fue modificado.',
                        ),
                    ],
                  ),
                ),
              ),
              if (fresh)
                BottomActions(
                  children: <Widget>[
                    PrimaryButton(
                      label: 'Listo',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

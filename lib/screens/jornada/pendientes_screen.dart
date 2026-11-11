import 'package:flutter/material.dart';

import '../../data/lapso_api.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../web_handoff.dart';

/// Registros hechos sin conexión: los que faltan por enviar y los que el
/// servidor rechazó.
class PendientesScreen extends StatefulWidget {
  const PendientesScreen({super.key});

  @override
  State<PendientesScreen> createState() => _PendientesScreenState();
}

class _PendientesScreenState extends State<PendientesScreen> {
  bool _busy = false;

  Future<void> _sync() async {
    final AppController c = AppScope.read(context);
    final int before = c.rejections.length;
    setState(() => _busy = true);
    String message;
    try {
      final int accepted = await c.syncPending();
      final int rejected = c.rejections.length - before;
      message = accepted == 1
          ? 'Se envió 1 registro.'
          : 'Se enviaron $accepted registros.';
      if (rejected > 0) {
        message += rejected == 1
            ? ' 1 fue rechazado.'
            : ' $rejected fueron rechazados.';
      }
    } on LapsoException catch (e) {
      message = e.message;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showLapsoSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final List<TimeEvent> pending = c.pending;
    final List<Rejection> rejections = c.rejections;
    final bool empty = pending.isEmpty && rejections.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Registros sin conexión')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: <Widget>[
                  if (empty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Column(
                        children: <Widget>[
                          StateBadge(icon: Icons.cloud_done_outlined),
                          SizedBox(height: 16),
                          Text(
                            'Todo está enviado',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: LapsoColors.navy,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'No tienes registros guardados en este teléfono.',
                            textAlign: TextAlign.center,
                            style: LapsoText.secondary,
                          ),
                        ],
                      ),
                    ),
                  if (pending.isNotEmpty) ...<Widget>[
                    NoticeBanner(
                      tone: Tone.warn,
                      icon: Icons.cloud_off_outlined,
                      text: c.offline
                          ? 'Sin conexión. Se envían solos cuando vuelva la '
                              'señal; no hace falta abrir la app.'
                          : 'Hay conexión. Puedes enviarlos ahora.',
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel('Por enviar'),
                    LapsoCard(
                      child: DividedColumn(
                        children: <Widget>[
                          for (final TimeEvent e in pending)
                            _PendingRow(
                              title: eventLabel(e),
                              detail: '${capitalize(shortDate(e.at))} · '
                                  '${hhmm(e.at)} · hora de tu teléfono',
                              pill: const TonePill(
                                'Por enviar',
                                tone: Tone.warn,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (rejections.isNotEmpty) ...<Widget>[
                    const SectionLabel('Rechazados'),
                    LapsoCard(
                      child: DividedColumn(
                        children: <Widget>[
                          for (final Rejection r in rejections)
                            _PendingRow(
                              title: eventLabel(r.event),
                              detail:
                                  '${capitalize(shortDate(r.event.at))} · '
                                  '${hhmm(r.event.at)}\n${r.reason}',
                              pill: const TonePill(
                                'Rechazado',
                                tone: Tone.bad,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    LapsoCard(
                      child: NavRow(
                        title: 'Pedir la corrección en la web',
                        subtitle: 'Un registro rechazado no cuenta en tu '
                            'jornada hasta que se corrija.',
                        external: true,
                        onTap: () => openWeb(context, WebPage.correccion),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (pending.isNotEmpty)
              BottomActions(
                children: <Widget>[
                  PrimaryButton(
                    label: 'Enviar ahora',
                    icon: Icons.cloud_upload_outlined,
                    busy: _busy,
                    onPressed: _sync,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.title,
    required this.detail,
    required this.pill,
  });

  final String title;
  final String detail;
  final Widget pill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: LapsoText.label.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(detail, style: LapsoText.caption),
              ],
            ),
          ),
          const SizedBox(width: 12),
          pill,
        ],
      ),
    );
  }
}

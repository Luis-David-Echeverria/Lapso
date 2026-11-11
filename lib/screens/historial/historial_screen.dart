import 'package:flutter/material.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../jornada/comprobante_screen.dart';
import '../web_handoff.dart';

/// Historial: un día a la vez, con su resumen y sus registros.
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  /// Días hacia atrás desde hoy. 0 es hoy.
  int _daysAgo = 0;

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final DateTime now = c.now;
    final DateTime today = dayOf(now);
    final DateTime day = DateTime(today.year, today.month, today.day - _daysAgo);
    final List<TimeEvent> all = c.allEvents;
    final DateTime first = all.isEmpty ? today : dayOf(all.first.at);
    final bool canGoBack = day.isAfter(first);
    final bool canGoForward = _daysAgo > 0;
    final DaySummary summary = summarizeDay(day, all, now);
    final String relative = relativeDay(day, now);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Semantics(
            header: true,
            child: Text('Historial', style: LapsoText.heading(26)),
          ),
          const SizedBox(height: 14),
          LapsoCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Día anterior',
                  onPressed:
                      canGoBack ? () => setState(() => _daysAgo += 1) : null,
                  icon: const Icon(Icons.chevron_left),
                  color: LapsoColors.primaryDark,
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      children: <Widget>[
                        Text(
                          dayDate(day),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: LapsoColors.navy,
                          ),
                        ),
                        if (relative.isNotEmpty)
                          Text(relative, style: LapsoText.caption),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Día siguiente',
                  onPressed: canGoForward
                      ? () => setState(() => _daysAgo -= 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  color: LapsoColors.primaryDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (summary.events.isEmpty)
            const _EmptyDay()
          else ...<Widget>[
            _SummaryCard(summary: summary, today: _daysAgo == 0),
            const SizedBox(height: 20),
            const SectionLabel('Registros'),
            LapsoCard(
              child: DividedColumn(
                children: <Widget>[
                  for (final TimeEvent e in summary.events)
                    _HistoryRow(
                      event: e,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              ComprobanteScreen(event: e),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          LapsoCard(
            child: NavRow(
              title: '¿Algo no coincide?',
              subtitle: 'Pide la corrección de un registro en la web.',
              external: true,
              onTap: () => openWeb(context, WebPage.correccion),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return const LapsoCard(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: <Widget>[
          Icon(Icons.event_busy_outlined, size: 36, color: LapsoColors.muted),
          SizedBox(height: 10),
          Text(
            'Sin registros este día',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: LapsoColors.navy,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'No registraste entrada ni salida.',
            textAlign: TextAlign.center,
            style: LapsoText.secondary,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.today});

  final DaySummary summary;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final TimeEvent? entry = summary.entry;
    final TimeEvent? exit = summary.exit;
    final bool open = summary.incomplete;

    final String state;
    final Tone tone;
    if (!open) {
      state = 'Jornada completa';
      tone = Tone.good;
    } else if (today) {
      state = summary.status == WorkStatus.enPausa ? 'En pausa' : 'En curso';
      tone = Tone.info;
    } else {
      state = 'Sin salida';
      tone = Tone.warn;
    }

    return LapsoCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text('Tiempo trabajado', style: LapsoText.secondary),
              ),
              TonePill(state, tone: tone),
            ],
          ),
          const SizedBox(height: 2),
          Semantics(
            label: spoken(summary.worked),
            child: ExcludeSemantics(
              child: Text(
                human(summary.worked),
                style: LapsoText.heading(34),
              ),
            ),
          ),
          const SizedBox(height: 8),
          DividedColumn(
            children: <Widget>[
              InfoRow(
                label: 'Entrada',
                value: entry == null ? 'Sin entrada' : hhmm(entry.at),
              ),
              InfoRow(
                label: 'Salida',
                value: exit == null
                    ? (today ? 'Aún sin salida' : 'Sin salida')
                    : hhmm(exit.at),
                valueColor: exit == null && !today
                    ? LapsoColors.warnText
                    : LapsoColors.navy,
              ),
              InfoRow(label: 'Pausas', value: human(summary.pauses)),
              InfoRow(label: 'Presencia', value: human(summary.presence)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event, required this.onTap});

  final TimeEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PauseType? pause = event.pauseType;
    final String evidence = evidenceSummary(event.evidence);
    final int? seq = event.seq;
    final List<String> details = <String>[
      if (pause != null) pauseLabel(pause),
      if (evidence.isNotEmpty) evidence,
      if (event.offline) 'Sin conexión',
      if (seq != null) 'Evento $seq' else 'Por enviar',
    ];
    return NavRow(
      title: eventLabel(event),
      subtitle: details.join(' · '),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            hhmm(event.at),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: LapsoColors.navy,
              fontFeatures: LapsoText.tabular,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 22, color: LapsoColors.muted),
        ],
      ),
    );
  }
}

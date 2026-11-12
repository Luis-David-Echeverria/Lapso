import 'package:flutter/material.dart';

import '../../config.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../jornada/comprobante_screen.dart';
import '../web_handoff.dart';

/// Historial: un día a la vez, con su resumen y sus registros. Los números
/// son los del servidor (`getMyTimesheets`), con correcciones ya aplicadas.
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
    final DateTime day =
        DateTime(today.year, today.month, today.day - _daysAgo);
    final bool isToday = _daysAgo == 0;
    final bool canGoBack = _daysAgo < kHistoryDays - 1;
    final bool canGoForward = _daysAgo > 0;
    final DaySummary? summary = c.dayAt(day);
    final String relative = relativeDay(day, now);

    final List<Widget> content;
    if (summary == null && !c.historyLoaded) {
      content = <Widget>[
        if (c.offline)
          const NoticeBanner(
            tone: Tone.warn,
            icon: Icons.cloud_off_outlined,
            text: 'Sin conexión. El historial se consulta en el servidor; '
                'desliza hacia abajo para intentarlo de nuevo.',
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
      ];
    } else if (summary == null || !summary.hasRecords) {
      content = const <Widget>[_EmptyDay()];
    } else {
      content = <Widget>[
        _SummaryCard(
          summary: summary,
          today: isToday,
          liveWorked: isToday ? c.worked : null,
          livePauses: isToday ? c.pauses : null,
        ),
        if (summary.events.isNotEmpty) ...<Widget>[
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
      ];
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: c.reloadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    onPressed: canGoBack
                        ? () => setState(() => _daysAgo += 1)
                        : null,
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
            ...content,
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
  const _SummaryCard({
    required this.summary,
    required this.today,
    this.liveWorked,
    this.livePauses,
  });

  final DaySummary summary;
  final bool today;

  /// Tiempos en vivo de la jornada abierta de hoy. El servidor solo da los
  /// totales de las jornadas ya cerradas.
  final Duration? liveWorked;
  final Duration? livePauses;

  @override
  Widget build(BuildContext context) {
    final DateTime? start = summary.start;
    final DateTime? end = summary.end;
    final bool open = summary.status == WorkStatus.enJornada ||
        summary.status == WorkStatus.enPausa;
    final Duration worked =
        open ? (liveWorked ?? summary.worked) : summary.worked;
    final Duration pauses =
        open ? (livePauses ?? summary.pauses) : summary.pauses;

    final String state;
    final Tone tone;
    if (summary.incomplete || (open && !today)) {
      state = 'Sin salida';
      tone = Tone.warn;
    } else if (open) {
      state = summary.status == WorkStatus.enPausa ? 'En pausa' : 'En curso';
      tone = Tone.info;
    } else {
      state = summary.corrected ? 'Corregida' : 'Jornada completa';
      tone = Tone.good;
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
            label: spoken(worked),
            child: ExcludeSemantics(
              child: Text(human(worked), style: LapsoText.heading(34)),
            ),
          ),
          const SizedBox(height: 8),
          DividedColumn(
            children: <Widget>[
              InfoRow(
                label: 'Entrada',
                value: start == null ? 'Sin entrada' : hhmm(start),
              ),
              InfoRow(
                label: 'Salida',
                value: end == null
                    ? (open && today ? 'Aún sin salida' : 'Sin salida')
                    : hhmm(end),
                valueColor: end == null && !(open && today)
                    ? LapsoColors.warnText
                    : LapsoColors.navy,
              ),
              InfoRow(label: 'Pausas', value: human(pauses)),
              InfoRow(label: 'Presencia', value: human(worked + pauses)),
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

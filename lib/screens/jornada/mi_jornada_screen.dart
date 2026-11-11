import 'package:flutter/material.dart';

import '../../data/lapso_api.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/hero_card.dart';
import 'comprobante_screen.dart';
import 'pendientes_screen.dart';
import 'register_flow.dart';
import 'sheets.dart';

/// Pestaña principal: el estado de la jornada y la acción que sigue.
class MiJornadaScreen extends StatefulWidget {
  const MiJornadaScreen({super.key, required this.onOpenHistory});

  final VoidCallback onOpenHistory;

  @override
  State<MiJornadaScreen> createState() => _MiJornadaScreenState();
}

class _MiJornadaScreenState extends State<MiJornadaScreen> {
  bool _busy = false;

  Future<void> _entrada() => startRegisterFlow(context, EventType.entrada);

  Future<void> _salida() async {
    if (AppScope.read(context).shouldWarnLongSession) {
      await _resolveLongSession();
      return;
    }
    await startRegisterFlow(context, EventType.salida);
  }

  Future<void> _resolveLongSession() async {
    final AppController c = AppScope.read(context);
    final List<TimeEvent> shift = c.shift;
    if (shift.isEmpty) return;
    final LongSessionChoice? choice = await showJornadaLargaSheet(
      context,
      since: shift.first.at,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case LongSessionChoice.newShift:
        await startRegisterFlow(
          context,
          EventType.entrada,
          forceNewEntry: true,
        );
      case LongSessionChoice.sameShift:
        c.dismissLongSession();
        if (c.status == WorkStatus.enJornada) {
          await startRegisterFlow(context, EventType.salida);
        } else {
          showLapsoSnack(
            context,
            'Primero reanuda tu jornada; después registra tu salida.',
          );
        }
    }
  }

  Future<void> _pausa() async {
    final PauseType? type = await showTipoPausaSheet(
      context,
      mealMinutes: AppScope.read(context).center?.mealMinutes ?? 60,
    );
    if (type == null || !mounted) return;
    await _quick(EventType.pausaInicio, pauseType: type);
  }

  /// Pausas y reanudaciones: se registran al momento, sin evidencia.
  Future<void> _quick(EventType type, {PauseType? pauseType}) async {
    final AppController c = AppScope.read(context);
    setState(() => _busy = true);
    String message;
    try {
      final TimeEvent e = await c.register(type, pauseType: pauseType);
      final String what = type == EventType.pausaInicio
          ? 'Pausa iniciada'
          : 'Jornada reanudada';
      message = e.pending
          ? '$what a las ${hhmm(e.at)}. Guardada en tu teléfono.'
          : '$what a las ${hhmm(e.at)}.';
    } on LapsoException catch (e) {
      message = e.message;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showLapsoSnack(context, message);
  }

  void _openPending() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const PendientesScreen(),
      ),
    );
  }

  void _openReceipt(TimeEvent e) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ComprobanteScreen(event: e),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final WorkStatus status = c.status;
    final List<TimeEvent> shift = c.shift;
    final int pending = c.pending.length;
    final int rejected = c.rejections.length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          _Header(
            name: c.employee?.firstName ?? '',
            initials: c.employee?.initials ?? '',
            date: longDate(c.now),
          ),
          const SizedBox(height: 16),
          if (c.offline) ...<Widget>[
            const NoticeBanner(
              tone: Tone.warn,
              icon: Icons.cloud_off_outlined,
              title: 'Sin conexión.',
              text: 'Puedes registrar: se guarda en tu teléfono y se envía '
                  'al reconectar.',
            ),
            const SizedBox(height: 12),
          ],
          if (pending > 0 || rejected > 0) ...<Widget>[
            LapsoCard(
              child: NavRow(
                icon: pending > 0
                    ? Icons.cloud_upload_outlined
                    : Icons.error_outline,
                title: _pendingTitle(pending, rejected),
                subtitle: pending > 0
                    ? 'Guardados en este teléfono.'
                    : 'Revisa el motivo y pide la corrección.',
                onTap: _openPending,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (c.shouldWarnLongSession) ...<Widget>[
            _LongSessionCard(onResolve: _resolveLongSession),
            const SizedBox(height: 12),
          ],
          TickBuilder(builder: (BuildContext context) => _hero(c, status)),
          const SizedBox(height: 20),
          ..._actions(c, status),
          if (shift.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            SectionLabel(
              isSameDay(shift.first.at, c.now)
                  ? 'Registros de hoy'
                  : 'Registros de esta jornada',
            ),
            LapsoCard(
              child: DividedColumn(
                children: <Widget>[
                  for (final TimeEvent e in shift.reversed)
                    _EventRow(event: e, onTap: () => _openReceipt(e)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _pendingTitle(int pending, int rejected) {
    if (pending > 0) {
      return pending == 1
          ? '1 registro por enviar'
          : '$pending registros por enviar';
    }
    return rejected == 1
        ? '1 registro rechazado'
        : '$rejected registros rechazados';
  }

  Widget _hero(AppController c, WorkStatus status) {
    final DateTime now = c.now;
    final WorkCenter? center = c.center;
    final List<TimeEvent> shift = c.shift;

    switch (status) {
      case WorkStatus.sinEntrada:
        return HeroCard(
          children: <Widget>[
            const HeroPill(
              'Sin entrada registrada',
              dot: LapsoColors.onNavyMuted,
            ),
            const SizedBox(height: 16),
            HeroFigure(
              label: 'Hora actual',
              value: hhmmss(now),
              spokenValue: hhmm(now),
            ),
            if (center != null) ...<Widget>[
              const HeroDivider(),
              HeroStats(
                items: <MapEntry<String, String>>[
                  MapEntry<String, String>('Centro', center.name),
                  MapEntry<String, String>('Horario', _schedule(center)),
                ],
              ),
            ],
          ],
        );

      case WorkStatus.enJornada:
        final Duration worked = c.worked;
        final Duration? target = center == null ? null : _target(center);
        final DateTime? end = c.scheduledEnd;
        return HeroCard(
          children: <Widget>[
            const HeroPill('En jornada', dot: LapsoColors.goodDot),
            const SizedBox(height: 16),
            HeroFigure(
              label: 'Tiempo trabajado',
              value: clock(worked),
              spokenValue: spoken(worked),
            ),
            if (target != null && target > Duration.zero) ...<Widget>[
              const SizedBox(height: 14),
              _Progress(
                value: worked.inSeconds / target.inSeconds,
                label: 'Jornada de ${human(target)}',
              ),
            ],
            const HeroDivider(),
            HeroStats(
              items: <MapEntry<String, String>>[
                MapEntry<String, String>('Entrada', hhmm(shift.first.at)),
                MapEntry<String, String>('Pausas', human(c.pauses)),
                if (end != null)
                  MapEntry<String, String>('Salida prevista', hhmm(end)),
              ],
            ),
          ],
        );

      case WorkStatus.enPausa:
        final TimeEvent? open = openPause(shift);
        final DateTime since = open?.at ?? now;
        final Duration inPause = now.difference(since);
        final PauseType? type = open?.pauseType;
        String? note;
        if (type == PauseType.comida && center != null) {
          final Duration left =
              Duration(minutes: center.mealMinutes) - inPause;
          note = left.isNegative
              ? 'Pasaste los ${center.mealMinutes} min de comida por '
                  '${human(-left)}.'
              : 'Te quedan ${human(left)} de comida.';
        }
        return HeroCard(
          children: <Widget>[
            HeroPill(
              type == null ? 'En pausa' : 'En pausa · ${pauseLabel(type)}',
              dot: LapsoColors.amber,
            ),
            const SizedBox(height: 16),
            HeroFigure(
              label: 'Tiempo en pausa',
              value: clock(inPause),
              spokenValue: spoken(inPause),
              note: note,
            ),
            const HeroDivider(),
            HeroStats(
              items: <MapEntry<String, String>>[
                MapEntry<String, String>('Inicio de pausa', hhmm(since)),
                MapEntry<String, String>('Trabajado', human(c.worked)),
              ],
            ),
          ],
        );

      case WorkStatus.terminada:
        return HeroCard(
          children: <Widget>[
            const HeroPill(
              'Jornada terminada',
              dot: LapsoColors.goodDot,
              icon: Icons.check_circle,
            ),
            const SizedBox(height: 16),
            HeroFigure(
              label: 'Tiempo trabajado',
              value: human(c.worked),
              spokenValue: spoken(c.worked),
              size: 44,
            ),
            const HeroDivider(),
            HeroStats(
              items: <MapEntry<String, String>>[
                MapEntry<String, String>('Entrada', hhmm(shift.first.at)),
                MapEntry<String, String>('Salida', hhmm(shift.last.at)),
                MapEntry<String, String>('Pausas', human(c.pauses)),
              ],
            ),
          ],
        );
    }
  }

  List<Widget> _actions(AppController c, WorkStatus status) {
    switch (status) {
      case WorkStatus.sinEntrada:
        return <Widget>[
          Center(
            child: _BigAction(
              label: 'Registrar entrada',
              icon: Icons.login,
              onPressed: _entrada,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _evidenceHint(c.center),
            textAlign: TextAlign.center,
            style: LapsoText.caption,
          ),
        ];
      case WorkStatus.enJornada:
        return <Widget>[
          PrimaryButton(
            label: 'Registrar salida',
            icon: Icons.logout,
            onPressed: _busy ? null : _salida,
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Iniciar pausa',
            icon: Icons.pause,
            onPressed: _busy ? null : _pausa,
          ),
        ];
      case WorkStatus.enPausa:
        return <Widget>[
          PrimaryButton(
            label: 'Reanudar jornada',
            icon: Icons.play_arrow,
            busy: _busy,
            onPressed: () => _quick(EventType.pausaFin),
          ),
          const SizedBox(height: 12),
          const Text(
            'Para registrar tu salida, primero reanuda tu jornada.',
            textAlign: TextAlign.center,
            style: LapsoText.caption,
          ),
        ];
      case WorkStatus.terminada:
        return <Widget>[
          const NoticeBanner(
            tone: Tone.good,
            icon: Icons.check_circle_outline,
            text: 'Tu jornada quedó registrada. Puedes revisarla en tu '
                'historial.',
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Ver mi historial',
            icon: Icons.calendar_today_outlined,
            onPressed: widget.onOpenHistory,
          ),
          TextButton(
            onPressed: _entrada,
            child: const Text('Registrar otra entrada'),
          ),
        ];
    }
  }

  static String _schedule(WorkCenter center) =>
      '${two(center.startHour)}:00 a ${two(center.endHour)}:00';

  /// Tiempo de trabajo esperado: el horario menos la comida.
  static Duration _target(WorkCenter center) =>
      Duration(hours: center.endHour - center.startHour) -
      Duration(minutes: center.mealMinutes);

  static String _evidenceHint(WorkCenter? center) {
    if (center == null) return '';
    final List<String> asks = <String>[
      if (center.requiresQr) 'el QR de tu centro',
      if (center.requiresLocation) 'tu ubicación',
      if (center.requiresPhoto) 'una foto',
    ];
    if (asks.isEmpty) return 'Se registra con la hora del servidor.';
    final String list = asks.length == 1
        ? asks.first
        : '${asks.sublist(0, asks.length - 1).join(', ')} y ${asks.last}';
    return 'Al registrar se pedirá $list.';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.initials,
    required this.date,
  });

  final String name;
  final String initials;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  name.isEmpty ? 'Hola' : 'Hola, $name',
                  style: LapsoText.heading(26),
                ),
              ),
              const SizedBox(height: 2),
              Text(date, style: LapsoText.secondary),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: LapsoColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: LapsoColors.primaryDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Avance de la jornada. El texto dice lo mismo que la barra.
class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final double v = value.clamp(0.0, 1.0);
    final int percent = (v * 100).round();
    return Semantics(
      label: '$label, $percent por ciento',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: LapsoColors.onNavyChip,
                color: LapsoColors.cyan,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$label · $percent %',
              style: const TextStyle(
                fontSize: 12,
                color: LapsoColors.onNavyMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón circular grande para la acción del día.
class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: LapsoColors.primarySoft,
        ),
        padding: const EdgeInsets.all(12),
        child: Material(
          color: LapsoColors.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 176,
              height: 176,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, size: 40, color: Colors.white),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LongSessionCard extends StatelessWidget {
  const _LongSessionCard({required this.onResolve});

  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: LapsoColors.warnBg,
        borderRadius: BorderRadius.circular(LapsoRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.schedule, size: 20, color: LapsoColors.warn),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tu jornada lleva más de $kLongSessionHours horas abierta. '
                  '¿Olvidaste registrar tu salida?',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: LapsoColors.warnText,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onResolve,
              style: TextButton.styleFrom(
                foregroundColor: LapsoColors.warnText,
              ),
              child: const Text('Revisar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap});

  final TimeEvent event;
  final VoidCallback onTap;

  static IconData _icon(EventType t) {
    switch (t) {
      case EventType.entrada:
        return Icons.login;
      case EventType.salida:
        return Icons.logout;
      case EventType.pausaInicio:
        return Icons.pause;
      case EventType.pausaFin:
        return Icons.play_arrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final PauseType? pause = event.pauseType;
    final String evidence = evidenceSummary(event.evidence);
    final List<String> details = <String>[
      if (pause != null) pauseLabel(pause),
      if (evidence.isNotEmpty) evidence,
      if (event.pending) 'Por enviar',
    ];
    return NavRow(
      icon: _icon(event.type),
      title: eventLabel(event),
      subtitle: details.isEmpty ? null : details.join(' · '),
      bold: true,
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

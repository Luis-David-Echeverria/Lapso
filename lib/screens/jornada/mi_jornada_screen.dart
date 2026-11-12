import 'package:flutter/material.dart';

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
  Future<void> _start(EventType type, {PauseType? pauseType}) {
    return startRegisterFlow(context, type, pauseType: pauseType);
  }

  Future<void> _entrada() async {
    if (AppScope.read(context).shouldWarnLongSession) {
      await _resolveLongSession();
      return;
    }
    await _start(EventType.entrada);
  }

  Future<void> _salida() async {
    if (AppScope.read(context).shouldWarnLongSession) {
      await _resolveLongSession();
      return;
    }
    await _start(EventType.salida);
  }

  /// Jornada abierta de más de 16 horas: se pregunta qué registrar.
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
        await _start(EventType.salida);
    }
  }

  Future<void> _pausa() async {
    final PauseType? type = await showTipoPausaSheet(context);
    if (type == null || !mounted) return;
    await _start(EventType.pausaInicio, pauseType: type);
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
      child: RefreshIndicator(
        onRefresh: c.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            _Header(
              name: c.employee?.firstName ?? '',
              initials: c.employee?.initials ?? '',
              date: longDate(c.now),
            ),
            const SizedBox(height: 16),
            if (c.offline) ...<Widget>[
              NoticeBanner(
                tone: Tone.warn,
                icon: Icons.cloud_off_outlined,
                title: 'Sin conexión.',
                text: c.capture.offlineAllowed
                    ? 'Puedes registrar: se guarda en tu teléfono y se envía '
                        'al reconectar.'
                    : 'Ves la última información guardada. Para registrar '
                        'necesitas conexión.',
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
            ] else if (c.hasIncompleteSession) ...<Widget>[
              const NoticeBanner(
                tone: Tone.warn,
                icon: Icons.history_toggle_off,
                text: 'Tienes una jornada reciente sin salida registrada. '
                    'Revísala en tu historial y pide la corrección.',
              ),
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
    final String center = c.centerName;
    final List<TimeEvent> shift = c.shift;
    final DateTime? end = c.scheduledEnd;

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
            if (center.isNotEmpty || end != null) ...<Widget>[
              const HeroDivider(),
              HeroStats(
                items: <MapEntry<String, String>>[
                  if (center.isNotEmpty)
                    MapEntry<String, String>('Centro', center),
                  if (end != null)
                    MapEntry<String, String>('Salida prevista', hhmm(end)),
                ],
              ),
            ],
          ],
        );

      case WorkStatus.enJornada:
        final Duration worked = c.worked;
        return HeroCard(
          children: <Widget>[
            const HeroPill('En jornada', dot: LapsoColors.goodDot),
            const SizedBox(height: 16),
            HeroFigure(
              label: 'Tiempo trabajado',
              value: clock(worked),
              spokenValue: spoken(worked),
            ),
            const HeroDivider(),
            HeroStats(
              items: <MapEntry<String, String>>[
                if (shift.isNotEmpty)
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
              note: 'El tiempo en pausa no cuenta como tiempo trabajado.',
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
            if (shift.isNotEmpty) ...<Widget>[
              const HeroDivider(),
              HeroStats(
                items: <MapEntry<String, String>>[
                  MapEntry<String, String>('Entrada', hhmm(shift.first.at)),
                  MapEntry<String, String>('Salida', hhmm(shift.last.at)),
                  MapEntry<String, String>('Pausas', human(c.pauses)),
                ],
              ),
            ],
          ],
        );
    }
  }

  /// Los botones salen de lo que el servidor acepta en este momento
  /// (`allowed_actions`), no de reglas propias de la app.
  List<Widget> _actions(AppController c, WorkStatus status) {
    final Set<EventType> allowed = c.allowedActions;
    final bool canEnter = allowed.contains(EventType.entrada);
    final bool canLeave = allowed.contains(EventType.salida);
    final bool canPause = allowed.contains(EventType.pausaInicio);
    final bool canResume = allowed.contains(EventType.pausaFin);

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
            _evidenceHint(c.capture, EventType.entrada),
            textAlign: TextAlign.center,
            style: LapsoText.caption,
          ),
        ];
      case WorkStatus.enJornada:
        return <Widget>[
          PrimaryButton(
            label: 'Registrar salida',
            icon: Icons.logout,
            onPressed: canLeave ? _salida : null,
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Iniciar pausa',
            icon: Icons.pause,
            onPressed: canPause ? _pausa : null,
          ),
        ];
      case WorkStatus.enPausa:
        return <Widget>[
          PrimaryButton(
            label: 'Reanudar jornada',
            icon: Icons.play_arrow,
            onPressed: canResume ? () => _start(EventType.pausaFin) : null,
          ),
          if (canLeave) ...<Widget>[
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Registrar salida',
              icon: Icons.logout,
              onPressed: _salida,
            ),
            const SizedBox(height: 12),
            const Text(
              'Si registras tu salida, la pausa se cierra en ese momento.',
              textAlign: TextAlign.center,
              style: LapsoText.caption,
            ),
          ],
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
          if (canEnter)
            TextButton(
              onPressed: _entrada,
              child: const Text('Registrar otra entrada'),
            ),
        ];
    }
  }

  static String _evidenceHint(CaptureSettings settings, EventType type) {
    final List<String> asks = <String>[
      if (settings.qr.asks(type)) 'el QR de tu centro',
      if (settings.location.asks(type)) 'tu ubicación',
      if (settings.photo.asks(type)) 'una foto',
    ];
    if (asks.isEmpty) return 'La hora de tu registro la pone el servidor.';
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

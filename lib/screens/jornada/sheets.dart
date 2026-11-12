import 'package:flutter/material.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../domain/rules.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Pide el tipo de pausa. Devuelve `null` si el usuario cerró la hoja.
Future<PauseType?> showTipoPausaSheet(BuildContext context) {
  return showModalBottomSheet<PauseType>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      Widget option(
        PauseType type,
        IconData icon,
        String detail,
      ) {
        return _SheetOption(
          icon: icon,
          title: pauseLabel(type),
          detail: detail,
          onTap: () => Navigator.of(context).pop(type),
        );
      }

      return _SheetBody(
        title: '¿Qué tipo de pausa es?',
        detail: 'El tiempo en pausa no cuenta como tiempo trabajado.',
        children: <Widget>[
          option(
            PauseType.comida,
            Icons.restaurant_outlined,
            'Tu tiempo para comer.',
          ),
          option(
            PauseType.personal,
            Icons.person_outline,
            'Un asunto tuyo, breve.',
          ),
          option(
            PauseType.autorizada,
            Icons.verified_outlined,
            'Con permiso de tu jefe o de Recursos Humanos.',
          ),
          option(
            PauseType.otra,
            Icons.more_horiz,
            'Cualquier otro motivo.',
          ),
        ],
      );
    },
  );
}

/// Qué hacer con una jornada que lleva más de 16 horas abierta.
enum LongSessionChoice { sameShift, newShift }

/// Pregunta si la jornada abierta sigue siendo la misma.
Future<LongSessionChoice?> showJornadaLargaSheet(
  BuildContext context, {
  required DateTime since,
}) {
  return showModalBottomSheet<LongSessionChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _SheetBody(
        title: 'Tu jornada lleva más de $kLongSessionHours horas abierta',
        detail: 'Tu entrada fue el ${dayDate(since).toLowerCase()} a las '
            '${hhmm(since)} y no tiene salida. ¿Qué quieres registrar?',
        children: <Widget>[
          _SheetOption(
            icon: Icons.login,
            title: 'Es una jornada nueva',
            detail: 'Registra una entrada. La jornada anterior queda sin '
                'salida y podrás pedir su corrección en la web.',
            onTap: () =>
                Navigator.of(context).pop(LongSessionChoice.newShift),
          ),
          _SheetOption(
            icon: Icons.logout,
            title: 'Sigo en la misma jornada',
            detail: 'Registra la salida de esa jornada con la hora de ahora.',
            onTap: () =>
                Navigator.of(context).pop(LongSessionChoice.sameShift),
          ),
        ],
      );
    },
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.detail,
    required this.children,
  });

  final String title;
  final String detail;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(title, style: LapsoText.heading(22)),
            ),
            const SizedBox(height: 6),
            Text(detail, style: LapsoText.secondary),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 4),
            SecondaryButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: LapsoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LapsoRadius.button),
          side: const BorderSide(color: LapsoColors.control),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: LapsoColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: LapsoColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: LapsoColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(detail, style: LapsoText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: LapsoColors.muted,
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

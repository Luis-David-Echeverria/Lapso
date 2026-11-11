import 'package:flutter/material.dart';

import '../../domain/format.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// La cuenta quedó bloqueada por intentos fallidos de PIN.
class BloqueadaScreen extends StatelessWidget {
  const BloqueadaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    return Scaffold(
      backgroundColor: LapsoColors.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                child: Column(
                  children: <Widget>[
                    Image.asset(
                      'assets/brand/lapso-lockup.png',
                      height: 50,
                      semanticLabel: 'Lapso Jornada',
                    ),
                    const SizedBox(height: 56),
                    const StateBadge(icon: Icons.lock_outline, tone: Tone.bad),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        'Tu cuenta está bloqueada',
                        textAlign: TextAlign.center,
                        style: LapsoText.heading(26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hubo demasiados intentos fallidos. Por seguridad no '
                      'puedes entrar por ahora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: LapsoColors.muted,
                      ),
                    ),
                    const SizedBox(height: 22),
                    TickBuilder(
                      builder: (BuildContext context) {
                        final Duration left = c.lockRemaining;
                        final bool done = left == Duration.zero;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: LapsoColors.ground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: LapsoColors.line),
                          ),
                          child: Semantics(
                            label: done
                                ? 'Ya puedes intentarlo de nuevo'
                                : 'Podrás intentarlo de nuevo en '
                                    '${left.inMinutes + 1} minutos',
                            child: ExcludeSemantics(
                              child: Column(
                                children: <Widget>[
                                  Text(
                                    done
                                        ? 'Ya puedes intentarlo de nuevo'
                                        : 'Podrás intentarlo de nuevo en',
                                    style: LapsoText.caption,
                                  ),
                                  if (!done) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      minSec(left),
                                      style: LapsoText.heading(40)
                                          .copyWith(height: 1),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const NoticeBanner(
                      text: '¿No recuerdas tu PIN? Pide a Recursos Humanos que '
                          'lo restablezca. Te darán uno temporal que '
                          'cambiarás al entrar.',
                    ),
                  ],
                ),
              ),
            ),
            BottomActions(
              children: <Widget>[
                TickBuilder(
                  builder: (BuildContext context) => SecondaryButton(
                    label: 'Volver al inicio de sesión',
                    onPressed: c.isLocked ? null : c.clearExpiredLock,
                  ),
                ),
                TextButton(
                  onPressed: c.forgetOrganization,
                  child: const Text('No es mi organización'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

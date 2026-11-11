import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Una evidencia que no se pudo reunir y el motivo.
class MissingEvidence {
  const MissingEvidence(this.what, this.why);
  final String what;
  final String why;
}

/// Alguna evidencia falló. El registro no se pierde: el usuario decide si
/// lo intenta de nuevo o registra sin ella. Devuelve `true` para registrar
/// de todos modos y `false` para reintentar.
class EvidenciaFallaScreen extends StatelessWidget {
  const EvidenciaFallaScreen({
    super.key,
    required this.title,
    required this.missing,
  });

  final String title;
  final List<MissingEvidence> missing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LapsoColors.surface,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  children: <Widget>[
                    const StateBadge(
                      icon: Icons.priority_high,
                      tone: Tone.warn,
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        'No pudimos reunir toda la evidencia',
                        textAlign: TextAlign.center,
                        style: LapsoText.heading(24),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tu registro no se pierde. Puedes intentarlo otra vez '
                      'o registrar ahora sin lo que faltó.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: LapsoColors.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    LapsoCard(
                      child: DividedColumn(
                        children: <Widget>[
                          for (final MissingEvidence m in missing)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Icon(
                                    Icons.error_outline,
                                    size: 20,
                                    color: LapsoColors.warn,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(m.what, style: LapsoText.label),
                                        const SizedBox(height: 2),
                                        Text(m.why, style: LapsoText.caption),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const NoticeBanner(
                      text: 'Si registras así, tu registro queda marcado y '
                          'Recursos Humanos lo verá.',
                    ),
                  ],
                ),
              ),
            ),
            BottomActions(
              children: <Widget>[
                PrimaryButton(
                  label: 'Intentar de nuevo',
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'Registrar de todos modos',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

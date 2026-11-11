import 'package:flutter/material.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Bitácora de quién consultó la ubicación o las fotos del trabajador.
class QuienVioScreen extends StatelessWidget {
  const QuienVioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<EvidenceView> views =
        AppScope.of(context).evidenceViews.reversed.toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Quién vio mis datos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Text(
                'Cada vez que alguien de tu organización abre tu ubicación o '
                'una foto tuya, queda anotado aquí con su motivo.',
                style: LapsoText.secondary,
              ),
            ),
            if (views.isEmpty)
              const LapsoCard(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 36,
                      color: LapsoColors.muted,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Nadie ha consultado tus datos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: LapsoColors.navy,
                      ),
                    ),
                  ],
                ),
              )
            else
              LapsoCard(
                child: DividedColumn(
                  children: <Widget>[
                    for (final EvidenceView v in views) _ViewRow(view: v),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewRow extends StatelessWidget {
  const _ViewRow({required this.view});

  final EvidenceView view;

  @override
  Widget build(BuildContext context) {
    final bool photo = view.what == Capability.foto;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            photo ? Icons.photo_camera_outlined : Icons.place_outlined,
            size: 20,
            color: LapsoColors.primaryDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  view.viewer,
                  style: LapsoText.label.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${photo ? 'Vio tu foto' : 'Vio tu ubicación'} · '
                  '${view.eventLabel}',
                  style: LapsoText.caption,
                ),
                Text('Motivo: ${view.reason}', style: LapsoText.caption),
                Text(dateTime(view.at), style: LapsoText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../config.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Fotos de los registros del trabajador, de los últimos
/// [kPhotoRetentionDays] días.
///
/// Punto de integración: cada imagen se pide con
/// `GET /me/events/{event_id}/photo`. Aquí se muestra un marcador.
class MisFotosScreen extends StatelessWidget {
  const MisFotosScreen({super.key});

  void _open(BuildContext context, TimeEvent e) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const AspectRatio(aspectRatio: 3 / 4, child: _PhotoPlaceholder()),
              const SizedBox(height: 12),
              Text(
                '${eventLabel(e)} · ${hhmm(e.at)}',
                style: LapsoText.label.copyWith(fontSize: 16),
              ),
              Text(longDate(e.at), style: LapsoText.caption),
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final DateTime limit =
        c.now.subtract(const Duration(days: kPhotoRetentionDays));
    final List<TimeEvent> photos = c.allEvents
        .where(
          (TimeEvent e) =>
              e.evidence.photoTaken == true && e.at.isAfter(limit),
        )
        .toList(growable: false)
        .reversed
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis fotos')),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Las fotos de tus registros de los últimos '
                  '$kPhotoRetentionDays días. Solo tú y las personas '
                  'autorizadas de tu organización pueden verlas.',
                  style: LapsoText.secondary,
                ),
              ),
            ),
            if (photos.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: LapsoCard(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: Column(
                      children: <Widget>[
                        Icon(
                          Icons.no_photography_outlined,
                          size: 36,
                          color: LapsoColors.muted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Aún no tienes fotos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: LapsoColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.66,
                  children: <Widget>[
                    for (final TimeEvent e in photos)
                      _PhotoTile(event: e, onTap: () => _open(context, e)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.event, required this.onTap});

  final TimeEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Foto de ${eventLabel(event).toLowerCase()}, '
          '${shortDate(event.at)}, ${hhmm(event.at)}',
      excludeSemantics: true,
      child: Material(
        color: LapsoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LapsoRadius.button),
          side: const BorderSide(color: LapsoColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Expanded(child: _PhotoPlaceholder(rounded: false)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${eventLabel(event)} · ${hhmm(event.at)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LapsoText.label,
                    ),
                    Text(
                      capitalize(shortDate(event.at)),
                      style: LapsoText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.rounded = true});

  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LapsoColors.placeholderBg,
        borderRadius: rounded ? BorderRadius.circular(16) : null,
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          size: 64,
          color: LapsoColors.placeholderLine,
        ),
      ),
    );
  }
}

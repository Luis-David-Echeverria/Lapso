import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../config.dart';
import '../../data/lapso_api.dart';
import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Fotos de los registros del trabajador que el servidor todavía conserva,
/// dentro del historial que la app consulta ([kHistoryDays] días).
///
/// Cada imagen se pide con `getMyEventPhoto` solo cuando se va a mostrar y
/// no se guarda en el teléfono.
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
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _EventPhoto(eventId: e.id),
                ),
              ),
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
    final List<TimeEvent> photos = c.photoEvents;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis fotos')),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Las fotos de tus registros de los últimos $kHistoryDays '
                  'días que aún se conservan. Las fotos se eliminan al '
                  'cumplirse el plazo de conservación.',
                  style: LapsoText.secondary,
                ),
              ),
            ),
            if (photos.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: LapsoCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: Column(
                      children: <Widget>[
                        const Icon(
                          Icons.no_photography_outlined,
                          size: 36,
                          color: LapsoColors.muted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          c.historyLoaded
                              ? 'No tienes fotos guardadas'
                              : 'Todavía no se pudo consultar tu historial',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
              Expanded(child: _EventPhoto(eventId: event.id)),
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

/// Pide la foto de un registro al servidor y la muestra.
class _EventPhoto extends StatefulWidget {
  const _EventPhoto({required this.eventId});

  final String eventId;

  @override
  State<_EventPhoto> createState() => _EventPhotoState();
}

class _EventPhotoState extends State<_EventPhoto> {
  bool _started = false;
  bool _loading = true;
  Uint8List? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    Uint8List? bytes;
    try {
      bytes = await AppScope.read(context).api.eventPhoto(widget.eventId);
    } on LapsoException {
      bytes = null;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _bytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = _bytes;
    const Widget placeholder = Center(
      child: Icon(Icons.person, size: 64, color: LapsoColors.placeholderLine),
    );
    return ColoredBox(
      color: LapsoColors.placeholderBg,
      child: _loading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          : bytes == null
              ? placeholder
              : Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stack,
                  ) =>
                      placeholder,
                ),
    );
  }
}

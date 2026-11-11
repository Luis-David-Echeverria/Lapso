import 'package:flutter/material.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../../theme/tokens.dart';
import 'evidencia_falla_screen.dart';
import 'foto_preview_screen.dart';

/// Título del flujo según lo que se registra.
String registerTitle(EventType type) {
  switch (type) {
    case EventType.entrada:
      return 'Registrar entrada';
    case EventType.salida:
      return 'Registrar salida';
    case EventType.pausaInicio:
      return 'Iniciar pausa';
    case EventType.pausaFin:
      return 'Reanudar jornada';
  }
}

/// Captura la evidencia del registro: una lectura de ubicación y una foto
/// con la cámara frontal. Devuelve la [Evidence] reunida, o `null` si el
/// usuario canceló.
///
/// Punto de integración: la vista de cámara es un marcador. Aquí va la
/// cámara frontal real (por ejemplo `camera`); la foto se envía después con
/// `POST /evidence/photos`.
class EvidenciaScreen extends StatefulWidget {
  const EvidenciaScreen({
    super.key,
    required this.type,
    required this.center,
    this.qrRead,
  });

  final EventType type;
  final WorkCenter center;

  /// Resultado del paso de QR. `null` si el centro no lo pide.
  final bool? qrRead;

  @override
  State<EvidenciaScreen> createState() => _EvidenciaScreenState();
}

class _EvidenciaScreenState extends State<EvidenciaScreen> {
  bool _started = false;
  bool _finishing = false;
  LocationResult? _location;
  Future<void>? _locationReading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.center.requiresLocation) _startReading();
  }

  void _startReading() {
    _locationReading = AppScope.read(context).readLocation().then(
      (LocationResult result) {
        if (mounted) setState(() => _location = result);
      },
    );
  }

  void _readLocation() {
    setState(() => _location = null);
    _startReading();
  }

  Future<void> _shoot() async {
    final bool? use = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const FotoPreviewScreen(),
      ),
    );
    if (use == true && mounted) await _finish(photoTaken: true);
  }

  Future<void> _finish({required bool photoTaken}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await _locationReading;
    if (!mounted) return;
    final AppController c = AppScope.read(context);
    final WorkCenter center = widget.center;
    final Evidence evidence = Evidence(
      qrRead: widget.qrRead,
      location: center.requiresLocation
          ? (_location ?? LocationResult.noDisponible)
          : null,
      photoTaken: center.requiresPhoto ? photoTaken : null,
    );

    final List<MissingEvidence> missing = <MissingEvidence>[
      if (evidence.qrRead == false)
        const MissingEvidence(
          'Código QR',
          'No se leyó el código QR del centro.',
        ),
      if (evidence.location != null && !evidence.locationOk)
        MissingEvidence('Ubicación', _locationProblem(evidence.location!)),
      if (evidence.photoTaken == false)
        MissingEvidence(
          'Foto',
          c.consent(Capability.foto)
              ? 'No se tomó la foto.'
              : 'No aceptaste la captura de foto. Puedes cambiarlo en '
                  'Más, en Mis datos de captura.',
        ),
    ];

    if (missing.isEmpty) {
      Navigator.of(context).pop(evidence);
      return;
    }
    final bool? goOn = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => EvidenciaFallaScreen(
          title: registerTitle(widget.type),
          missing: missing,
        ),
      ),
    );
    if (!mounted) return;
    if (goOn == true) {
      Navigator.of(context).pop(evidence);
      return;
    }
    setState(() => _finishing = false);
    if (center.requiresLocation && !evidence.locationOk) _readLocation();
  }

  static String _locationProblem(LocationResult r) {
    switch (r) {
      case LocationResult.dentro:
      case LocationResult.dentroBajaPrecision:
        return '';
      case LocationResult.fuera:
        return 'Tu ubicación quedó fuera de la zona del centro.';
      case LocationResult.sinPermiso:
        return 'El teléfono no le dio permiso de ubicación a la app.';
      case LocationResult.sinConsentimiento:
        return 'No aceptaste la captura de ubicación. Puedes cambiarlo en '
            'Más, en Mis datos de captura.';
      case LocationResult.noDisponible:
        return 'No se pudo obtener tu ubicación.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final WorkCenter center = widget.center;
    final bool camera = center.requiresPhoto && c.consent(Capability.foto);
    final LocationResult? location = _location;

    return Scaffold(
      backgroundColor: LapsoColors.night,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Cancelar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      registerTitle(widget.type),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        camera
                            ? 'Tómate una foto para tu registro'
                            : 'Reuniendo la evidencia de tu registro',
                        textAlign: TextAlign.center,
                        style: LapsoText.heading(22, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      camera
                          ? 'Usa la cámara frontal y que tu cara quede dentro '
                              'del óvalo.'
                          : 'Solo toma un momento.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: LapsoColors.onNavySoft,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (camera) ...<Widget>[
                      const _CameraPlaceholder(),
                      const SizedBox(height: 16),
                    ],
                    if (widget.qrRead != null)
                      _EvidenceLine(
                        icon: Icons.qr_code_2,
                        label: 'Código QR',
                        value: widget.qrRead! ? 'Leído' : 'Sin leer',
                        ok: widget.qrRead!,
                      ),
                    if (center.requiresLocation)
                      _EvidenceLine(
                        icon: Icons.place_outlined,
                        label: 'Ubicación',
                        value: location == null
                            ? 'Leyendo una sola vez…'
                            : locationLabel(location),
                        ok: location == null
                            ? null
                            : (location == LocationResult.dentro ||
                                location ==
                                    LocationResult.dentroBajaPrecision),
                      ),
                    if (center.requiresPhoto && !camera)
                      const _EvidenceLine(
                        icon: Icons.photo_camera_outlined,
                        label: 'Foto',
                        value: 'Sin consentimiento',
                        ok: false,
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (camera) ...<Widget>[
                    Center(
                      child: _Shutter(onPressed: _finishing ? null : _shoot),
                    ),
                    TextButton(
                      onPressed: _finishing
                          ? null
                          : () => _finish(photoTaken: false),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('No puedo tomar la foto'),
                    ),
                  ] else
                    FilledButton(
                      onPressed: _finishing
                          ? null
                          : () => _finish(photoTaken: false),
                      child: _finishing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continuar'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vista de la cámara frontal',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B1B45),
              borderRadius: BorderRadius.circular(28),
            ),
            alignment: Alignment.center,
            child: FractionallySizedBox(
              widthFactor: 0.62,
              heightFactor: 0.72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(
                    Radius.elliptical(200, 260),
                  ),
                  border: Border.all(color: LapsoColors.cyan, width: 3),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_outline,
                    size: 96,
                    color: Color(0xFF2A3F78),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String value;

  /// `null` mientras se lee.
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final bool? state = ok;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: LapsoColors.onNavyChip,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Semantics(
          liveRegion: true,
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: LapsoColors.onNavySoft),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: LapsoColors.onNavySoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (state == null)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: LapsoColors.cyan,
                  ),
                )
              else
                Icon(
                  state ? Icons.check_circle : Icons.error_outline,
                  size: 20,
                  color: state ? LapsoColors.goodDot : LapsoColors.amber,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: 'Tomar foto',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 4),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: onPressed == null
                    ? LapsoColors.onNavyMuted
                    : Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

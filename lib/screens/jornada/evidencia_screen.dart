import 'package:flutter/material.dart';

import '../../domain/format.dart';
import '../../domain/models.dart';
import '../../platform/device_capture.dart';
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

/// Lo que se reunió del teléfono para un registro.
class EvidenceResult {
  const EvidenceResult({this.location, this.photo});
  final LocationReading? location;
  final PhotoCapture? photo;
}

/// Reúne la evidencia del registro: una lectura de ubicación y una foto con
/// la cámara frontal, según lo que pida el centro y lo que la persona haya
/// aceptado. Devuelve un [EvidenceResult], o `null` si la persona canceló.
///
/// Nada bloquea: si algo falta, la persona decide si lo intenta de nuevo o
/// registra sin eso.
class EvidenciaScreen extends StatefulWidget {
  const EvidenciaScreen({
    super.key,
    required this.type,
    required this.qrAsked,
    this.qr,
  });

  final EventType type;

  /// El centro pide QR para este registro.
  final bool qrAsked;

  /// El QR leído en el paso anterior, si se leyó.
  final QrReading? qr;

  @override
  State<EvidenciaScreen> createState() => _EvidenciaScreenState();
}

class _EvidenciaScreenState extends State<EvidenciaScreen> {
  bool _started = false;
  bool _busy = false;
  LocationReading? _location;
  bool _readingLocation = false;
  Future<void>? _locationReading;
  PhotoCapture? _photo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final AppController c = AppScope.read(context);
    final CaptureRule rule = c.capture.location;
    if (rule.asks(widget.type) && rule.active) {
      _readingLocation = true;
      _startReading(c);
    }
  }

  void _startReading(AppController c) {
    _locationReading = c.device.readLocation().then(
      (LocationReading reading) {
        if (!mounted) return;
        setState(() {
          _location = reading;
          _readingLocation = false;
        });
      },
    );
  }

  void _readAgain() {
    setState(() {
      _location = null;
      _readingLocation = true;
    });
    _startReading(AppScope.read(context));
  }

  Future<void> _shoot() async {
    final AppController c = AppScope.read(context);
    setState(() => _busy = true);
    final PhotoCapture capture = await c.device.takePhoto();
    if (!mounted) return;
    if (capture.cancelled) {
      setState(() => _busy = false);
      return;
    }
    if (!capture.taken) {
      setState(() {
        _busy = false;
        _photo = capture;
      });
      await _finish();
      return;
    }
    final bool? use = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            FotoPreviewScreen(bytes: capture.bytes!),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (use == true) {
      _photo = capture;
      await _finish();
    }
  }

  Future<void> _withoutPhoto() async {
    _photo = const PhotoCapture.unavailable('NO_DISPONIBLE');
    await _finish();
  }

  static String _locationProblem(LocationReading? reading) {
    if (reading?.status == 'DENEGADO') {
      return 'El teléfono no le dio permiso de ubicación a la app.';
    }
    return 'No se pudo obtener tu ubicación.';
  }

  static String _photoProblem(PhotoCapture? photo) {
    if (photo?.status == 'DENEGADO') {
      return 'El teléfono no le dio permiso de cámara a la app.';
    }
    return 'No se tomó la foto.';
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _locationReading;
    if (!mounted) return;
    final AppController c = AppScope.read(context);
    final CaptureSettings settings = c.capture;
    final CaptureRule location = settings.location;
    final CaptureRule photo = settings.photo;
    const String noConsent = 'No aceptaste esta captura. Puedes cambiarlo en '
        'Más, en Mis datos de captura.';
    String mark(CaptureRule rule, String text) =>
        rule.mode == CaptureMode.required
            ? '$text Tu centro la pide como obligatoria.'
            : text;

    final LocationReading? reading = _location;
    final PhotoCapture? shot = _photo;
    final List<MissingEvidence> missing = <MissingEvidence>[
      if (widget.qrAsked && widget.qr == null)
        const MissingEvidence(
          'Código QR',
          'No se leyó el código QR del centro.',
        ),
      if (location.asks(widget.type) &&
          (!location.active || reading == null || !reading.hasCoordinates))
        MissingEvidence(
          'Ubicación',
          mark(
            location,
            location.active ? _locationProblem(reading) : noConsent,
          ),
        ),
      if (photo.asks(widget.type) && (shot == null || !shot.taken))
        MissingEvidence(
          'Foto',
          mark(photo, photo.active ? _photoProblem(shot) : noConsent),
        ),
    ];

    final EvidenceResult result =
        EvidenceResult(location: reading, photo: shot);
    if (missing.isEmpty) {
      Navigator.of(context).pop(result);
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
      Navigator.of(context).pop(result);
      return;
    }
    // Reintentar: se vuelve a leer la ubicación si fue lo que falló.
    setState(() {
      _busy = false;
      _photo = null;
    });
    if (location.asks(widget.type) &&
        location.active &&
        (reading == null || !reading.hasCoordinates)) {
      _readAgain();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final CaptureSettings settings = c.capture;
    final CaptureRule location = settings.location;
    final CaptureRule photo = settings.photo;
    final bool locationAsked = location.asks(widget.type);
    final bool photoAsked = photo.asks(widget.type);
    final bool camera = photoAsked && photo.active;
    final LocationReading? reading = _location;

    final String locationValue;
    final bool? locationOk;
    if (!location.active) {
      locationValue = 'Sin tu aceptación';
      locationOk = false;
    } else if (_readingLocation || reading == null) {
      locationValue = 'Leyendo una sola vez…';
      locationOk = null;
    } else if (reading.hasCoordinates) {
      locationValue = 'Lista';
      locationOk = true;
    } else {
      locationValue = reading.status == 'DENEGADO'
          ? locationLabel(LocationResult.sinPermiso)
          : locationLabel(LocationResult.noDisponible);
      locationOk = false;
    }

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
                          ? 'Se abrirá la cámara frontal. Que tu cara se vea '
                              'completa y con buena luz.'
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
                      const _CameraHint(),
                      const SizedBox(height: 16),
                    ],
                    if (widget.qrAsked)
                      _EvidenceLine(
                        icon: Icons.qr_code_2,
                        label: 'Código QR',
                        value: widget.qr != null ? 'Leído' : 'Sin leer',
                        ok: widget.qr != null,
                      ),
                    if (locationAsked)
                      _EvidenceLine(
                        icon: Icons.place_outlined,
                        label: 'Ubicación',
                        value: locationValue,
                        ok: locationOk,
                      ),
                    if (photoAsked && !camera)
                      const _EvidenceLine(
                        icon: Icons.photo_camera_outlined,
                        label: 'Foto',
                        value: 'Sin tu aceptación',
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
                    FilledButton.icon(
                      onPressed: _busy ? null : _shoot,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Tomar foto'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _withoutPhoto,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('No puedo tomar la foto'),
                    ),
                  ] else
                    FilledButton(
                      onPressed: _busy ? null : _finish,
                      child: _busy
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

/// Ilustración que anticipa la foto. La cámara que se abre es la del sistema.
class _CameraHint extends StatelessWidget {
  const _CameraHint();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1B45),
          borderRadius: BorderRadius.circular(28),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 120,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(60, 75)),
            border: Border.all(color: LapsoColors.cyan, width: 3),
          ),
          child: const Center(
            child: Icon(
              Icons.person_outline,
              size: 72,
              color: Color(0xFF2A3F78),
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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config.dart';
import '../domain/models.dart';
import 'device_capture.dart';

/// Capturas reales con los plugins `geolocator`, `image_picker` y
/// `mobile_scanner`.
///
/// Reglas que cumple (contrato de la API y políticas de las tiendas):
/// - La ubicación se lee una sola vez, en primer plano, solo al registrar.
///   La app nunca pide ubicación en segundo plano.
/// - La cámara se abre solo cuando la persona toca el botón; la foto no
///   pasa por la galería ni se guarda en el teléfono.
/// - Si la persona niega un permiso, se devuelve el motivo y el registro
///   sigue adelante.
class RealDeviceCapture implements DeviceCapture {
  RealDeviceCapture();

  final ImagePicker _picker = ImagePicker();

  @override
  Future<LocationReading> readLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationReading.unavailable('NO_DISPONIBLE');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationReading.unavailable('DENEGADO');
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LocationReading.coordinates(
        lat: position.latitude,
        lon: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: DateTime.now(),
      );
    } on Exception {
      // Sin señal, tiempo agotado o servicio apagado.
      return const LocationReading.unavailable('NO_DISPONIBLE');
    }
  }

  @override
  Future<PhotoCapture> takePhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: kPhotoMaxSide,
        maxHeight: kPhotoMaxSide,
        imageQuality: 60,
        requestFullMetadata: false,
      );
      if (file == null) return const PhotoCapture.cancelled();
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > kPhotoMaxBytes) {
        // El servidor no acepta fotos de más de 300 KB.
        return const PhotoCapture.unavailable('NO_DISPONIBLE');
      }
      return PhotoCapture.taken(bytes, DateTime.now());
    } on Exception catch (e) {
      final String text = '$e'.toLowerCase();
      if (text.contains('denied') || text.contains('permission')) {
        return const PhotoCapture.unavailable('DENEGADO');
      }
      return const PhotoCapture.unavailable('NO_DISPONIBLE');
    }
  }

  @override
  Widget buildQrScanner({required ValueChanged<String> onCode}) {
    return _QrScanner(onCode: onCode);
  }
}

class _QrScanner extends StatefulWidget {
  const _QrScanner({required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<_QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<_QrScanner> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final Barcode barcode in capture.barcodes) {
      final String? value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _done = true;
        widget.onCode(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(onDetect: _onDetect);
  }
}

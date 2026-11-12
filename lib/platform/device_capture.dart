import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Foto tomada con la cámara, o el motivo de no tenerla.
class PhotoCapture {
  const PhotoCapture.taken(Uint8List this.bytes, DateTime this.capturedAt)
      : status = null;

  /// [status] es `DENEGADO`, `NO_SOPORTADO` o `NO_DISPONIBLE`.
  const PhotoCapture.unavailable(String this.status)
      : bytes = null,
        capturedAt = null;

  /// La persona cerró la cámara sin tomar la foto.
  const PhotoCapture.cancelled()
      : bytes = null,
        capturedAt = null,
        status = null;

  /// JPEG de hasta 1,024 px por lado.
  final Uint8List? bytes;
  final DateTime? capturedAt;
  final String? status;

  bool get taken => bytes != null;
  bool get cancelled => bytes == null && status == null;
}

/// Lo que la app le pide al teléfono: una lectura de ubicación, una foto
/// con la cámara frontal y el lector de QR.
///
/// `RealDeviceCapture` usa los plugins; `FakeDeviceCapture` simula todo para
/// el modo de demostración y las pruebas.
abstract class DeviceCapture {
  /// Una sola lectura puntual, de 8 segundos como máximo. Nunca seguimiento
  /// ni segundo plano. Pide el permiso del sistema si hace falta.
  Future<LocationReading> readLocation();

  /// Abre la cámara frontal y devuelve la foto.
  Future<PhotoCapture> takePhoto();

  /// Vista del lector de QR. Llama a [onCode] con el contenido del código en
  /// cuanto lo lee.
  Widget buildQrScanner({required ValueChanged<String> onCode});
}

/// Capturas simuladas. No toca la cámara ni la ubicación del teléfono.
class FakeDeviceCapture implements DeviceCapture {
  /// Simula que el sistema negó el permiso de ubicación.
  bool locationPermission = true;

  /// Contenido del QR que "lee" el botón de simular.
  String qrPayload = 'https://validacion.lapsojornada.mx/q/DEMOqrTOKEN123456'
      '?k=DEMOcode12345678';

  @override
  Future<LocationReading> readLocation() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!locationPermission) {
      return const LocationReading.unavailable('DENEGADO');
    }
    return LocationReading.coordinates(
      lat: 19.43261,
      lon: -99.13321,
      accuracyMeters: 12,
      capturedAt: DateTime.now(),
    );
  }

  @override
  Future<PhotoCapture> takePhoto() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return PhotoCapture.taken(_demoJpeg, DateTime.now());
  }

  @override
  Widget buildQrScanner({required ValueChanged<String> onCode}) {
    return Stack(
      children: <Widget>[
        const Center(
          child: Icon(Icons.qr_code_2, size: 120, color: Color(0xFF2A3F78)),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: FilledButton(
            onPressed: () => onCode(qrPayload),
            child: const Text('Simular lectura'),
          ),
        ),
      ],
    );
  }
}

/// Una imagen JPEG mínima (1 × 1 px), para que el flujo simulado tenga algo
/// que mostrar y subir.
final Uint8List _demoJpeg = Uint8List.fromList(const <int>[
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, //
  0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
  0x00, 0x03, 0x02, 0x02, 0x02, 0x02, 0x02, 0x03, 0x02, 0x02, 0x02, 0x03,
  0x03, 0x03, 0x03, 0x04, 0x06, 0x04, 0x04, 0x04, 0x04, 0x04, 0x08, 0x06,
  0x06, 0x05, 0x06, 0x09, 0x08, 0x0A, 0x0A, 0x09, 0x08, 0x09, 0x09, 0x0A,
  0x0C, 0x0F, 0x0C, 0x0A, 0x0B, 0x0E, 0x0B, 0x09, 0x09, 0x0D, 0x11, 0x0D,
  0x0E, 0x0F, 0x10, 0x10, 0x11, 0x10, 0x0A, 0x0C, 0x12, 0x13, 0x12, 0x10,
  0x13, 0x0F, 0x10, 0x10, 0x10, 0xFF, 0xC9, 0x00, 0x0B, 0x08, 0x00, 0x01,
  0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xCC, 0x00, 0x06, 0x00, 0x10,
  0x10, 0x05, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
  0xD2, 0xCF, 0x20, 0xFF, 0xD9,
]);

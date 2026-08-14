import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../scanner/engine/scanner_capabilities.dart';

/// Servicio de detección runtime de capacidades del dispositivo.
class ScannerCapabilitiesService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Detecta qué modos están disponibles en este dispositivo.
  static Future<ScannerCapabilities> detect() async {
    final cameraStatus = await Permission.camera.status;
    final hasCamera = cameraStatus.isGranted || await Permission.camera.request().isGranted;

    bool hasArCore = false;
    bool hasArKit = false;

    if (Platform.isAndroid) {
      // Detección heurística: ARCore requiere Android 7.0+ (API 24)
      // y ciertos hardware. Para producción, usar arcore_client o
      // verificar via Google Play Services.
      final androidInfo = await _deviceInfo.androidInfo;
      hasArCore = hasCamera && (androidInfo.version.sdkInt >= 24);
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      // ARKit desde iOS 11. Aproximamos por versión mayor.
      final versionParts = iosInfo.systemVersion.split('.');
      final major = int.tryParse(versionParts.first) ?? 0;
      hasArKit = hasCamera && major >= 11;
    }

    // Sensores: solo verificamos si hay stream disponible
    bool hasGyro = false;
    bool hasAccel = false;
    try {
      await gyroscopeEvents.first.timeout(const Duration(milliseconds: 500));
      hasGyro = true;
    } catch (_) {}
    try {
      await accelerometerEvents.first.timeout(const Duration(milliseconds: 500));
      hasAccel = true;
    } catch (_) {}

    return ScannerCapabilities(
      hasCamera: hasCamera,
      hasArCore: hasArCore,
      hasArKit: hasArKit,
      hasGyroscope: hasGyro,
      hasAccelerometer: hasAccel,
    );
  }
}

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../scanner/engine/scanner_capabilities.dart';

/// Servicio de detección runtime de capacidades del dispositivo.
class ScannerCapabilitiesService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<ScannerCapabilities> detect() async {
    final cameraStatus = await Permission.camera.status;
    final hasCamera = cameraStatus.isGranted ||
        await Permission.camera.request().isGranted;

    bool hasArCore = false;
    bool hasArKit = false;

    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      // Heurística: ARCore requiere Android 7.0+ (API 24).
      // Detección real de instalación requiere platform channel.
      hasArCore = hasCamera && (androidInfo.version.sdkInt >= 24);
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      final versionParts = iosInfo.systemVersion.split('.');
      final major = int.tryParse(versionParts.first) ?? 0;
      hasArKit = hasCamera && major >= 11;
    }

    // Detección de sensores: escuchamos por 300 ms.
    bool hasGyro = false;
    bool hasAccel = false;

    try {
      await gyroscopeEventStream()
          .first
          .timeout(const Duration(milliseconds: 300));
      hasGyro = true;
    } catch (_) {}

    try {
      await accelerometerEventStream()
          .first
          .timeout(const Duration(milliseconds: 300));
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

import 'scanner_mode.dart';

/// Capacidades físicas/software relevantes para Scanner Engine.
class ScannerCapabilities {
  final bool hasCamera;
  final bool hasArCore;
  final bool hasArKit;
  final bool hasGyroscope;
  final bool hasAccelerometer;

  const ScannerCapabilities({
    this.hasCamera = false,
    this.hasArCore = false,
    this.hasArKit = false,
    this.hasGyroscope = false,
    this.hasAccelerometer = false,
  });

  /// El dispositivo puede utilizar algún motor AR.
  bool get supportsAR => hasArCore || hasArKit;

  /// El dispositivo puede utilizar el scanner básico (cámara + sensores).
  bool get supportsBasic => hasCamera && (hasGyroscope || hasAccelerometer);

  /// Siempre disponible: dibujo manual.
  bool get supportsManual => true;

  /// Modo recomendado según hardware.
  ScannerMode get recommendedMode {
    if (supportsAR) return ScannerMode.ar;
    if (supportsBasic) return ScannerMode.basic;
    return ScannerMode.manual;
  }

  @override
  String toString() {
    return 'ScannerCapabilities('
        'camera: $hasCamera, '
        'arCore: $hasArCore, '
        'arKit: $hasArKit, '
        'gyro: $hasGyroscope, '
        'accel: $hasAccelerometer, '
        'recommended: ${recommendedMode.name})';
  }
}

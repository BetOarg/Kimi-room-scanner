import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/scanner_mode.dart';
import '../models/scanner_point.dart';
import 'scanner_adapter.dart';

/// Adapter "Basic": cámara + giroscopio para dispositivos sin ARCore.
/// Estrategia: el usuario apunta, presiona captura, y la app proyecta
/// usando la orientación del giroscopio + una distancia ingresada o estimada.
class BasicScannerAdapter extends ScannerAdapter {
  CameraController? _camera;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  // Orientación acumulada (yaw en radianes, plano XZ)
  double _yaw = 0.0;
  DateTime? _lastGyroTime;

  ScannerPoint? _lastPoint;
  double? _calibrationDistance; // Distancia de referencia en metros

  @override
  ScannerMode get mode => ScannerMode.basic;

  @override
  bool get isAvailable => true;

  @override
  bool get isTracking => _camera?.value.isInitialized ?? false;

  CameraController? get camera => _camera;

  @override
  Future<void> initialize() async {
    final cameras = await availableCameras();
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _camera = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _camera!.initialize();

    _lastGyroTime = DateTime.now();
    _gyroSub = gyroscopeEvents.listen((event) {
      final now = DateTime.now();
      if (_lastGyroTime == null) {
        _lastGyroTime = now;
        return;
      }
      final dt = now.difference(_lastGyroTime!).inMilliseconds / 1000.0;
      _lastGyroTime = now;

      // Integración simple del yaw (eje Z del giroscopio)
      // En la práctica, el eje depende de la orientación del dispositivo.
      _yaw += event.z * dt;
    });
  }

  /// Establece la distancia de referencia (metros) antes de capturar.
  void setCalibrationDistance(double meters) {
    _calibrationDistance = meters;
  }

  @override
  Future<ScannerPoint?> capturePoint() async {
    if (!_camera!.value.isInitialized) return null;

    // Primer punto = origen
    if (_lastPoint == null) {
      const origin = ScannerPoint(x: 0, y: 0, z: 0, accuracy: 0.1, source: PointSource.camera);
      _lastPoint = origin;
      return origin;
    }

    final distance = _calibrationDistance ?? 2.5;

    final dx = distance * cos(_yaw);
    final dz = distance * sin(_yaw);

    final point = ScannerPoint(
      x: _lastPoint!.x + dx,
      y: 0,
      z: _lastPoint!.z + dz,
      accuracy: 0.20,
      source: PointSource.camera,
    );

    _lastPoint = point;
    return point;
  }

  @override
  Future<void> dispose() async {
    await _gyroSub?.cancel();
    await _camera?.dispose();
    _camera = null;
  }
}

import 'dart:math';
import '../models/scanner_mode.dart';
import '../models/scanner_point.dart';
import 'scanner_adapter.dart';

/// Adapter para dibujo manual 2D.
/// El usuario indica distancia y ángulo relativo desde la última esquina.
class ManualScannerAdapter extends ScannerAdapter {
  final List<ScannerPoint> _points = [];
  double _lastAngle = 0.0;

  @override
  ScannerMode get mode => ScannerMode.manual;

  @override
  bool get isAvailable => true;

  @override
  bool get isTracking => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<ScannerPoint?> capturePoint() async => null;

  /// Agrega un vértice relativo al último punto conocido.
  /// [distance] en metros.
  /// [angleDeg] ángulo en grados respecto al eje +X (0° = derecha, 90° = arriba).
  /// [height] altura Y (normalmente 0 para plano de planta).
  ScannerPoint addVertex(double distance, double angleDeg, {double height = 0.0}) {
    final angleRad = angleDeg * (pi / 180.0);

    final last = _points.isEmpty
        ? const ScannerPoint(x: 0, y: 0, z: 0)
        : _points.last;

    final x = last.x + distance * cos(angleRad);
    final z = last.z + distance * sin(angleRad);

    final point = ScannerPoint(
      x: x,
      y: height,
      z: z,
      accuracy: 0.05,
      source: PointSource.manual,
    );

    _points.add(point);
    _lastAngle = angleDeg;
    return point;
  }

  /// Inserta un punto absoluto (usado por el canvas táctil 2D).
  ScannerPoint addAbsolutePoint(double x, double z, {double y = 0.0}) {
    final point = ScannerPoint(
      x: x,
      y: y,
      z: z,
      accuracy: 0.03,
      source: PointSource.manual,
    );
    _points.add(point);
    return point;
  }

  List<ScannerPoint> get points => List.unmodifiable(_points);

  void undo() {
    if (_points.isNotEmpty) _points.removeLast();
  }

  void reset() => _points.clear();
}

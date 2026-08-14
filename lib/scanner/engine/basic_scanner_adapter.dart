import 'dart:math';
import '../../models/room_model.dart';
import '../models/scanner_mode.dart';
import '../models/scanner_point.dart';
import 'scanner_adapter.dart';

class ManualScannerAdapter extends ScannerAdapter {
  final List<ScannerPoint> _points = [];
  double _scale = 0.01; // default: 100 px = 1 m

  @override
  ScannerMode get mode => ScannerMode.manual;

  @override
  bool get isAvailable => true;

  @override
  bool get isTracking => true;

  /// Metros por pixel. Ej: 0.01 = 1 metro cada 100 px.
  double get scale => _scale;

  set scale(double value) {
    if (value > 0) _scale = value;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<ScannerPoint?> capturePoint() async => null;

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
    return point;
  }

  /// Inserta un punto absoluto usando la escala actual.
  ScannerPoint addAbsolutePoint(double screenX, double screenY, {double height = 0.0}) {
    final x = screenX * _scale;
    final z = screenY * _scale;

    final point = ScannerPoint(
      x: x,
      y: height,
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

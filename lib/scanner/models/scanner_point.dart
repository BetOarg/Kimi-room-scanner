import '../../models/room_model.dart';

/// Punto normalizado del Scanner Engine.
class ScannerPoint {
  final double x;
  final double y;
  final double z;
  final double accuracy;
  final PointSource source;

  const ScannerPoint({
    required this.x,
    required this.y,
    required this.z,
    this.accuracy = 0.0,
    this.source = PointSource.manual,
  });

  /// Convierte al modelo de dominio preservando el origen.
  ARPoint toARPoint() {
    return ARPoint(
      x: x,
      y: y,
      z: z,
      source: source,
    );
  }

  factory ScannerPoint.fromARPoint(
    ARPoint point, {
    double accuracy = 0.0,
  }) {
    return ScannerPoint(
      x: point.x,
      y: point.y,
      z: point.z,
      accuracy: accuracy,
      source: point.source ?? PointSource.ar,
    );
  }

  ScannerPoint copyWith({
    double? x,
    double? y,
    double? z,
    double? accuracy,
    PointSource? source,
  }) {
    return ScannerPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      accuracy: accuracy ?? this.accuracy,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'z': z,
      'accuracy': accuracy,
      'source': source.name,
    };
  }

  factory ScannerPoint.fromJson(Map json) {
    return ScannerPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      source: PointSource.values.firstWhere(
        (value) => value.name == json['source'],
        orElse: () => PointSource.manual,
      ),
    );
  }
}

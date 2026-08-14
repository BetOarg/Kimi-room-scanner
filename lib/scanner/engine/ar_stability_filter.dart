import 'dart:math';
import '../../models/room_model.dart';

/// Filtro de suavizado exponencial (EMA) para posiciones AR.
/// Reduce el ruido de captura cuando el usuario tiembla.
class ARStabilityFilter {
  double? _lastX;
  double? _lastY;
  double? _lastZ;

  /// Factor de suavizado: 0.0 = muy lento, 1.0 = sin filtro.
  /// 0.15 es un buen balance entre respuesta y estabilidad.
  final double alpha;

  ARStabilityFilter({this.alpha = 0.15});

  /// Resetea el estado interno (útil al reiniciar sesión AR).
  void reset() {
    _lastX = null;
    _lastY = null;
    _lastZ = null;
  }

  /// Aplica EMA a cada coordenada.
  ARPoint filter(ARPoint raw) {
    if (_lastX == null) {
      _lastX = raw.x;
      _lastY = raw.y;
      _lastZ = raw.z;
      return raw;
    }

    _lastX = _ema(_lastX!, raw.x);
    _lastY = _ema(_lastY!, raw.y);
    _lastZ = _ema(_lastZ!, raw.z);

    return ARPoint(
      x: _lastX!,
      y: _lastY!,
      z: _lastZ!,
      source: raw.source,
    );
  }

  double _ema(double prev, double current) {
    return prev + alpha * (current - prev);
  }
}

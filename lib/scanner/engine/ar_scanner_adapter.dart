import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import '../../models/room_model.dart';
import '../models/scanner_mode.dart';
import '../models/scanner_point.dart';
import 'scanner_adapter.dart';
import 'ar_stability_filter.dart';

/// Adapter que envuelve ar_flutter_plugin_2 (ARCore/ARKit).
/// Incluye filtro de estabilidad para reducir ruido de captura.
class ArScannerAdapter extends ScannerAdapter {
  ARSessionManager? _sessionManager;
  ARObjectManager? _objectManager;
  bool _isInitialized = false;
  final ARStabilityFilter _filter = ARStabilityFilter(alpha: 0.15);

  @override
  ScannerMode get mode => ScannerMode.ar;

  @override
  bool get isAvailable => true;

  @override
  bool get isTracking => _sessionManager != null && _isInitialized;

  /// Callback expuesto para que la UI conecte ARView.
  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    _sessionManager = sessionManager;
    _objectManager = objectManager;

    _sessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handleTaps: false,
    );
    _objectManager!.onInitialize();
    _isInitialized = true;
  }

  @override
  Future<void> initialize() async {
    _filter.reset();
    _isInitialized = false;
  }

  @override
  Future<ScannerPoint?> capturePoint() async {
    if (_sessionManager == null) return null;

    final pose = await _sessionManager!.getCameraPose();
    if (pose == null) return null;

    final t = pose.getTranslation();
    final raw = ARPoint(x: t.x, y: t.y, z: t.z, source: PointSource.ar);
    final smoothed = _filter.filter(raw);

    return ScannerPoint(
      x: smoothed.x,
      y: smoothed.y,
      z: smoothed.z,
      accuracy: 0.02,
      source: PointSource.ar,
    );
  }

  @override
  Future<void> dispose() async {
    await _sessionManager?.dispose();
    _sessionManager = null;
    _objectManager = null;
    _isInitialized = false;
  }
}

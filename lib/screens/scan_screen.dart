import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import '../providers/scanner_provider.dart';
import '../providers/floor_plan_provider.dart';
import '../scanner/engine/scanner_engine.dart';
import '../scanner/engine/scanner_adapter.dart';
import '../scanner/engine/scanner_capabilities.dart';
import '../scanner/engine/ar_scanner_adapter.dart';
import '../scanner/engine/basic_scanner_adapter.dart';
import '../scanner/engine/manual_scanner_adapter.dart';
import '../scanner/models/scanner_mode.dart';
import '../services/scanner_capabilities_service.dart';
import '../services/permission_service.dart';
import 'floor_plan_viewer_screen.dart';
import 'manual_scan_screen.dart';
import 'basic_scan_screen.dart';

class ScanScreen extends StatefulWidget {
  final String projectUuid;
  final String projectName;

  const ScanScreen({
    super.key,
    required this.projectUuid,
    required this.projectName,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ScannerEngine _engine = ScannerEngine();
  ScannerCapabilities? _caps;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final granted = await PermissionService.requestScannerPermissions();
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _error = 'Permisos de cámara/ubicación denegados.';
          _initializing = false;
        });
        return;
      }

      _caps = await ScannerCapabilitiesService.detect();

      ScannerAdapter adapter;
      switch (_caps!.recommendedMode) {
        case ScannerMode.ar:
          adapter = ArScannerAdapter();
          break;
        case ScannerMode.basic:
          adapter = BasicScannerAdapter();
          break;
        case ScannerMode.manual:
          adapter = ManualScannerAdapter();
          break;
        default:
          adapter = ManualScannerAdapter();
      }

      await _engine.initialize(adapter);

      if (!mounted) return;
      context.read<ScannerProvider>().startNewRoom();
      setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  Future<void> _onCapture() async {
    HapticFeedback.lightImpact();
    final point = await _engine.capturePoint();
    if (!mounted) return;

    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo capturar la posición. Intenta de nuevo.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = context.read<ScannerProvider>();
    final result = provider.tryAddPoint(point.x, point.y, point.z);

    if (!result.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Punto inválido.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else if (result.warningMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.warningMessage!),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onCloseRoom() async {
    HapticFeedback.mediumImpact();
    final provider = context.read<ScannerProvider>();
    final closedRoom = provider.closeCurrentRoom();

    if (!mounted) return;
    if (closedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.lastCloseError ?? 'No se pudo cerrar la habitación.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await context.read<FloorPlanProvider>().addCompletedRoom(closedRoom);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Ambiente guardado correctamente!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  void _openFloorPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FloorPlanViewerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final mode = _engine.mode;
    switch (mode) {
      case ScannerMode.ar:
        return _buildARScreen();
      case ScannerMode.basic:
        return BasicScanScreen(
          engine: _engine,
          projectUuid: widget.projectUuid,
          projectName: widget.projectName,
        );
      case ScannerMode.manual:
        return ManualScanScreen(
          engine: _engine,
          projectUuid: widget.projectUuid,
          projectName: widget.projectName,
        );
      default:
        return ManualScanScreen(
          engine: _engine,
          projectUuid: widget.projectUuid,
          projectName: widget.projectName,
        );
    }
  }

  Widget _buildARScreen() {
    final provider = context.watch<ScannerProvider>();
    final arAdapter = _engine.adapter as ArScannerAdapter;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          ARView(
            onARViewCreated: arAdapter.onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Center(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
            ),
          ),
          _buildHud(provider),
          _buildControls(provider),
        ],
      ),
    );
  }

  Widget _buildHud(ScannerProvider provider) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Chip(
            avatar: const Icon(Icons.meeting_room, size: 16, color: Colors.white),
            label: Text(provider.currentRoom?.name ?? 'Nuevo Ambiente'),
            backgroundColor: Colors.black87,
            labelStyle: const TextStyle(color: Colors.white),
          ),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Ver plano',
                onPressed: _openFloorPlan,
                icon: const Icon(Icons.map_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: Icon(
                  Icons.circle,
                  size: 10,
                  color: provider.isTrackingOk ? Colors.greenAccent : Colors.orangeAccent,
                ),
                label: Text(provider.isTrackingOk ? 'AR Activo' : 'Calibrando...'),
                backgroundColor: Colors.black87,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ScannerProvider provider) {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (provider.currentPointsCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  'Esquinas: ${provider.currentPointsCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: provider.currentPointsCount > 0
                    ? () {
                        HapticFeedback.lightImpact();
                        provider.removeLastPoint();
                      }
                    : null,
                icon: const Icon(Icons.undo),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _onCapture,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('AÑADIR ESQUINA'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: provider.currentPointsCount >= 3 ? _onCloseRoom : null,
                icon: const Icon(Icons.check),
                style: IconButton.styleFrom(
                  backgroundColor: provider.currentPointsCount >= 3 ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
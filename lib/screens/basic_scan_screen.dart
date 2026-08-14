import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/room_model.dart';
import '../providers/scanner_provider.dart';
import '../providers/floor_plan_provider.dart';
import '../scanner/engine/scanner_engine.dart';
import '../scanner/engine/basic_scanner_adapter.dart';
import 'floor_plan_viewer_screen.dart';

enum AppMode { wall, door, window }

class BasicScanScreen extends StatefulWidget {
  final ScannerEngine engine;
  final String projectUuid;
  final String projectName;

  const BasicScanScreen({
    super.key,
    required this.engine,
    required this.projectUuid,
    required this.projectName,
  });

  @override
  State<BasicScanScreen> createState() => _BasicScanScreenState();
}

class _BasicScanScreenState extends State<BasicScanScreen> {
  late final BasicScannerAdapter _adapter;
  final TextEditingController _distanceCtrl = TextEditingController(text: '2.5');
  AppMode _currentMode = AppMode.wall;
  Timer? _yawTimer;
  double _displayYaw = 0.0;
  bool _showCalibrationDialog = true;

  @override
  void initState() {
    super.initState();
    _adapter = widget.engine.adapter as BasicScannerAdapter;
    _yawTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() => _displayYaw = _adapter.yaw);
      }
    });
  }

  @override
  void dispose() {
    _yawTimer?.cancel();
    super.dispose();
  }

  void _showCalibrationSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calibración de distancia',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Parate en una esquina y apunta la cámara hacia la siguiente pared. '
                  'Ingresá la distancia real en metros:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _distanceCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Distancia a la pared (metros)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final dist = double.tryParse(_distanceCtrl.text);
                      if (dist != null && dist > 0) {
                        _adapter.setCalibrationDistance(dist);
                        Navigator.pop(ctx);
                        setState(() => _showCalibrationDialog = false);
                      }
                    },
                    child: const Text('CONFIRMAR Y COMENZAR'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onCapture() async {
    if (_showCalibrationDialog) {
      _showCalibrationSheet();
      return;
    }

    final dist = double.tryParse(_distanceCtrl.text);
    if (dist == null || dist <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa una distancia válida en metros.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _adapter.setCalibrationDistance(dist);
    HapticFeedback.lightImpact();

    final point = await widget.engine.capturePoint();
    if (!mounted) return;

    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de captura. Verifica que la cámara esté activa.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final provider = context.read<ScannerProvider>();

    if (_currentMode == AppMode.wall) {
      final result = provider.tryAddPoint(point);
      if (!result.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Punto inválido.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      if (provider.currentPointsCount < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Necesitas al menos 2 esquinas antes de agregar aberturas.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final featureType = _currentMode == AppMode.door
          ? FeatureType.door
          : FeatureType.window;
      provider.addFeatureToCurrentRoom(
        featureType,
        ARPoint(x: point.x, y: point.y, z: point.z, source: point.source),
      );
      final label = _currentMode == AppMode.door ? 'Puerta' : 'Ventana';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label marcada en la posición actual'),
          duration: const Duration(seconds: 1),
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
          content: Text(provider.lastCloseError ?? 'No se pudo cerrar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    await context.read<FloorPlanProvider>().addCompletedRoom(closedRoom);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Ambiente guardado!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  Widget _buildModeChip(AppMode mode, IconData icon, String label) {
    final isSelected = _currentMode == mode;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : Colors.white70,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: mode == AppMode.wall
          ? Colors.blueAccent
          : mode == AppMode.door
              ? Colors.redAccent
              : Colors.blue.shade300,
      backgroundColor: Colors.black87,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (!selected) return;
        HapticFeedback.selectionClick();
        setState(() => _currentMode = mode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScannerProvider>();
    final camera = _adapter.camera;
    final yawDeg = (_displayYaw * 180 / pi).toStringAsFixed(1);

    // Mostrar diálogo de calibración al inicio
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showCalibrationDialog && mounted) {
        _showCalibrationSheet();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (camera != null && camera.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(camera),
            )
          else
            const Center(child: CircularProgressIndicator()),
          Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(provider.currentRoom?.name ?? 'Nuevo Ambiente'),
                  backgroundColor: Colors.black87,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                IconButton.filledTonal(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FloorPlanViewerScreen()),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Corrección de yaw
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.rotate_left, color: Colors.white70),
                        tooltip: '-5°',
                        onPressed: () {
                          _adapter.correctYaw(-5);
                          setState(() => _displayYaw = _adapter.yaw);
                        },
                      ),
                      Text(
                        'Yaw: ${yawDeg}°',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.rotate_right, color: Colors.white70),
                        tooltip: '+5°',
                        onPressed: () {
                          _adapter.correctYaw(5);
                          setState(() => _displayYaw = _adapter.yaw);
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          _adapter.resetYaw();
                          setState(() => _displayYaw = _adapter.yaw);
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('RESET'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildModeChip(AppMode.wall, Icons.wallpaper, 'Pared'),
                    const SizedBox(width: 8),
                    _buildModeChip(AppMode.door, Icons.door_front_door, 'Puerta'),
                    const SizedBox(width: 8),
                    _buildModeChip(AppMode.window, Icons.window, 'Ventana'),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: RoomType.values.map((type) {
                      final isSelected = provider.selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(type.name.toUpperCase()),
                          selected: isSelected,
                          selectedColor: Colors.blueAccent,
                          backgroundColor: Colors.black87,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            provider.setRoomType(type);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Esquinas: ${provider.currentPointsCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _distanceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black87,
                          labelText: 'Distancia (m)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _onCapture,
                        icon: Icon(
                          _currentMode == AppMode.wall
                              ? Icons.add_location_alt_outlined
                              : _currentMode == AppMode.door
                                  ? Icons.door_front_door
                                  : Icons.window,
                        ),
                        label: Text(
                          _currentMode == AppMode.wall
                              ? 'AÑADIR ESQUINA'
                              : _currentMode == AppMode.door
                                  ? 'AÑADIR PUERTA'
                                  : 'AÑADIR VENTANA',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentMode == AppMode.wall
                              ? Colors.blueAccent
                              : _currentMode == AppMode.door
                                  ? Colors.redAccent
                                  : Colors.blue.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 8),
                const Text(
                  'Apunta la cámara hacia la siguiente esquina e ingresa la distancia.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

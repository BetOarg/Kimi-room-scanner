import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/room_model.dart';
import '../providers/scanner_provider.dart';
import '../providers/floor_plan_provider.dart';
import '../scanner/engine/scanner_engine.dart';
import '../scanner/engine/manual_scanner_adapter.dart';
import '../widgets/manual_floor_plan_painter.dart';
import 'floor_plan_viewer_screen.dart';

enum AppMode { wall, door, window }

class ManualScanScreen extends StatefulWidget {
  final ScannerEngine engine;
  final String projectUuid;
  final String projectName;

  const ManualScanScreen({
    super.key,
    required this.engine,
    required this.projectUuid,
    required this.projectName,
  });

  @override
  State<ManualScanScreen> createState() => _ManualScanScreenState();
}

class _ManualScanScreenState extends State<ManualScanScreen> {
  late final ManualScannerAdapter _adapter;
  final List<Offset> _canvasPoints = [];
  final TextEditingController _distanceCtrl = TextEditingController();
  final TextEditingController _angleCtrl = TextEditingController();
  AppMode _currentMode = AppMode.wall;

  @override
  void initState() {
    super.initState();
    _adapter = widget.engine.adapter as ManualScannerAdapter;
  }

  void _onCanvasTap(TapDownDetails details, Size canvasSize) {
    final local = details.localPosition;
    const scale = 0.01;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final meterPos = (local - center) * scale;

    final provider = context.read<ScannerProvider>();

    if (_currentMode == AppMode.wall) {
      final point = _adapter.addAbsolutePoint(meterPos.dx, meterPos.dy);
      setState(() => _canvasPoints.add(local));
      HapticFeedback.lightImpact();
      provider.tryAddPoint(point);
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
        ARPoint(x: meterPos.dx, y: 0, z: meterPos.dy, source: PointSource.manual),
      );
      HapticFeedback.lightImpact();
      final label = _currentMode == AppMode.door ? 'Puerta' : 'Ventana';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label marcada en el plano'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _onAddRelative() {
    final dist = double.tryParse(_distanceCtrl.text) ?? 0.0;
    final angle = double.tryParse(_angleCtrl.text) ?? 0.0;
    if (dist <= 0) return;

    final point = _adapter.addVertex(dist, angle);
    setState(() {});

    HapticFeedback.lightImpact();

    final provider = context.read<ScannerProvider>();
    provider.tryAddPoint(point);

    _distanceCtrl.clear();
    _angleCtrl.clear();
  }

  Future<void> _onCloseRoom() async {
    HapticFeedback.mediumImpact();
    final provider = context.read<ScannerProvider>();
    final closedRoom = provider.closeCurrentRoom();

    if (!mounted) return;
    if (closedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.lastCloseError ?? 'Error al cerrar.'),
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

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Dibujo Manual'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Ver plano',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FloorPlanViewerScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (d) => _onCanvasTap(d, constraints.biggest),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      size: constraints.biggest,
                      painter: ManualFloorPlanPainter(
                        points: _canvasPoints,
                        isClosed: provider.currentPointsCount >= 3,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
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
                  Text(
                    'Esquinas: ${provider.currentPointsCount}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _distanceCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Distancia (m)',
                            labelStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _angleCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Ángulo (°)',
                            labelStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _onAddRelative,
                        icon: const Icon(Icons.add),
                        label: const Text('AÑADIR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'O toca directamente en el canvas para colocar puntos.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: provider.currentPointsCount > 0
                            ? () {
                                HapticFeedback.lightImpact();
                                provider.removeLastPoint();
                                if (_canvasPoints.isNotEmpty) {
                                  setState(() => _canvasPoints.removeLast());
                                }
                              }
                            : null,
                        icon: const Icon(Icons.undo),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: provider.currentPointsCount >= 3 ? _onCloseRoom : null,
                          icon: const Icon(Icons.check),
                          label: const Text('CERRAR AMBIENTE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

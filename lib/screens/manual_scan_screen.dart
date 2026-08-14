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

  @override
  void initState() {
    super.initState();
    _adapter = widget.engine.adapter as ManualScannerAdapter;
  }

  void _onCanvasTap(TapDownDetails details, Size canvasSize) {
    final local = details.localPosition;
    // Convertir coordenadas de pantalla a metros (escala: 100 px = 1 metro)
    const scale = 0.01;
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final meterPos = (local - center) * scale;

    final point = _adapter.addAbsolutePoint(meterPos.dx, meterPos.dy);
    setState(() {
      _canvasPoints.add(local);
    });

    HapticFeedback.lightImpact();

    final provider = context.read<ScannerProvider>();
    provider.tryAddPoint(point.x, point.y, point.z);
  }

  void _onAddRelative() {
    final dist = double.tryParse(_distanceCtrl.text) ?? 0.0;
    final angle = double.tryParse(_angleCtrl.text) ?? 0.0;
    if (dist <= 0) return;

    final point = _adapter.addVertex(dist, angle);
    setState(() {});

    HapticFeedback.lightImpact();

    final provider = context.read<ScannerProvider>();
    provider.tryAddPoint(point.x, point.y, point.z);

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
      const SnackBar(content: Text('¡Ambiente guardado!'), backgroundColor: Colors.green),
    );
    Navigator.pop(context);
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
          // Canvas interactivo
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

          // Panel de controles
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
                  const SizedBox(height: 12),
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

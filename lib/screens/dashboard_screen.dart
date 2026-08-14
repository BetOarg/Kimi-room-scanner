import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/isar_models.dart';
import '../providers/project_provider.dart';
import '../providers/floor_plan_provider.dart';
import '../providers/scanner_provider.dart';
import '../scanner/models/scanner_mode.dart';
import '../services/scanner_capabilities_service.dart';
import '../services/auth_service.dart';
import 'scan_screen.dart';
import 'floor_plan_viewer_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectProvider>().init();
    });
  }

  void _showNewProjectDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Proyecto'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Ej: Remodelación Oficina',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _createProject(ctx, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _createProject(BuildContext dialogContext, String name) async {
    if (name.isEmpty) return;
    Navigator.pop(dialogContext);

    final uuid = DateTime.now().millisecondsSinceEpoch.toString();

    await context.read<ProjectProvider>().saveCurrentProject(
          uuid: uuid,
          name: name,
          rooms: const [],
        );

    if (!mounted) return;

    context.read<FloorPlanProvider>().loadProject(
          uuid: uuid,
          name: name,
          rooms: const [],
        );
    context.read<ScannerProvider>().loadRooms(const []);

    await _openScanner(context, uuid, name);
  }

  Future<void> _openProject(IsarProject project) async {
    final provider = context.read<ProjectProvider>();
    final rooms = await provider.selectProject(project);

    if (!mounted) return;

    context.read<FloorPlanProvider>().loadProject(
          uuid: project.uuid,
          name: project.name,
          rooms: rooms,
        );
    context.read<ScannerProvider>().loadRooms(rooms);

    await _openScanner(context, project.uuid, project.name);
  }

  Future<void> _openScanner(BuildContext ctx, String uuid, String name) async {
    final caps = await ScannerCapabilitiesService.detect();
    if (!ctx.mounted) return;

    final selectedMode = await showModalBottomSheet<ScannerMode>(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seleccionar modo de escaneo',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Recomendado: ${caps.recommendedMode.name.toUpperCase()}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                if (caps.supportsAR)
                  ListTile(
                    leading: const Icon(Icons.view_in_ar, color: Colors.purpleAccent),
                    title: const Text('Realidad Aumentada'),
                    subtitle: const Text('Mayor precisión. Requiere ARCore/ARKit.'),
                    onTap: () => Navigator.pop(sheetCtx, ScannerMode.ar),
                  ),
                if (caps.supportsBasic)
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                    title: const Text('Cámara + Sensores'),
                    subtitle: const Text('Usa giroscopio. Ingresa distancias manualmente.'),
                    onTap: () => Navigator.pop(sheetCtx, ScannerMode.basic),
                  ),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.greenAccent),
                  title: const Text('Dibujo Manual 2D'),
                  subtitle: const Text('Crea el plano tocando la pantalla o ingresando medidas.'),
                  onTap: () => Navigator.pop(sheetCtx, ScannerMode.manual),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (selectedMode == null || !ctx.mounted) return;

    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          projectUuid: uuid,
          projectName: name,
          forcedMode: selectedMode,
        ),
      ),
    );
  }

  Future<void> _viewFloorPlan(IsarProject project) async {
    final provider = context.read<ProjectProvider>();
    final rooms = await provider.selectProject(project);

    if (!mounted) return;

    context.read<FloorPlanProvider>().loadProject(
          uuid: project.uuid,
          name: project.name,
          rooms: rooms,
        );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FloorPlanViewerScreen()),
    );
  }

  void _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final user = _authService.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Proyectos'),
        elevation: 2,
        actions: [
          IconButton(
            icon

import 'package:flutter/foundation.dart';
import '../models/room_model.dart';
import '../scanner/models/scanner_point.dart';
import '../utils/scan_validator.dart';

class ScannerProvider extends ChangeNotifier {
  final List<RoomModel> _rooms = [];
  RoomModel? _currentRoom;
  RoomType _selectedType = RoomType.living;
  bool _isTrackingOk = false;

  List<RoomModel> get rooms => List.unmodifiable(_rooms);
  RoomModel? get currentRoom => _currentRoom;
  RoomType get selectedType => _selectedType;
  bool get isTrackingOk => _isTrackingOk;
  int get currentPointsCount => _currentRoom?.points.length ?? 0;

  void updateTrackingStatus(bool status) {
    if (_isTrackingOk != status) {
      _isTrackingOk = status;
      notifyListeners();
    }
  }

  void setRoomType(RoomType type) {
    _selectedType = type;
    if (_currentRoom != null) {
      _currentRoom = _currentRoom!.copyWith(
        type: type,
        name: _getRoomTypeName(type),
      );
    }
    notifyListeners();
  }

  void startNewRoom() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentRoom = RoomModel(
      id: newId,
      name: _getRoomTypeName(_selectedType),
      type: _selectedType,
      points: [],
    );
    notifyListeners();
  }

  void loadRooms(List<RoomModel> rooms) {
    _rooms
      ..clear()
      ..addAll(rooms);
    _currentRoom = null;
    notifyListeners();
  }

  /// Ahora acepta ScannerPoint para preservar el origen (AR, camera, manual).
  ValidationResult tryAddPoint(ScannerPoint point) {
    if (_currentRoom == null) {
      startNewRoom();
    }

    final candidate = point.toARPoint();
    final result = ScanValidator.validateNewPoint(candidate, _currentRoom!.points);

    if (!result.isValid) {
      return result;
    }

    final updatedPoints = List<ARPoint>.from(_currentRoom!.points)..add(candidate);
    _currentRoom = _currentRoom!.copyWith(points: updatedPoints);
    notifyListeners();
    return result;
  }

  void addFeatureToCurrentRoom(FeatureType type, ARPoint location) {
    if (_currentRoom == null) return;

    final width = type == FeatureType.door ? 0.8 : 1.0;
    final end = ARPoint(x: location.x + width, y: location.y, z: location.z);

    final feature = WallFeature(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      start: location,
      end: end,
    );

    final updatedFeatures = List<WallFeature>.from(_currentRoom!.features)..add(feature);
    _currentRoom = _currentRoom!.copyWith(features: updatedFeatures);
    notifyListeners();
  }

  void removeLastPoint() {
    if (_currentRoom == null || _currentRoom!.points.isEmpty) return;
    final updatedPoints = List<ARPoint>.from(_currentRoom!.points)..removeLast();
    _currentRoom = _currentRoom!.copyWith(points: updatedPoints);
    notifyListeners();
  }

  String? lastCloseError;

  RoomModel? closeCurrentRoom() {
    lastCloseError = null;
    final room = _currentRoom;
    if (room == null) {
      lastCloseError = 'No hay una habitación en curso.';
      return null;
    }

    final closure = ScanValidator.validateClosure(room.points);
    if (!closure.isValid) {
      lastCloseError = closure.errorMessage;
      return null;
    }

    if (ScanValidator.hasSelfIntersections(room.points)) {
      lastCloseError = 'El contorno se autointersecta. Revisa las paredes trazadas.';
      return null;
    }

    final closedRoom = room.copyWith(isClosed: true);
    _rooms.add(closedRoom);
    _currentRoom = null;
    notifyListeners();
    return closedRoom;
  }

  String _getRoomTypeName(RoomType type) {
    switch (type) {
      case RoomType.living:
        return 'Living';
      case RoomType.cocina:
        return 'Cocina';
      case RoomType.bano:
        return 'Baño';
      case RoomType.dormitorio:
        return 'Dormitorio';
      case RoomType.lavadero:
        return 'Lavadero';
      case RoomType.pasillo:
        return 'Pasillo';
    }
  }
}

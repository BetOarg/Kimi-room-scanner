import 'dart:ui';
import 'package:flutter/material.dart';

/// Painter para el canvas de dibujo manual 2D.
class ManualFloorPlanPainter extends CustomPainter {
  final List<Offset> points;
  final bool isClosed;

  ManualFloorPlanPainter({
    required this.points,
    this.isClosed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Dibujar grilla de referencia
    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;

    const step = 50.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Ejes centrales
    final axisPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      axisPaint,
    );
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      axisPaint,
    );

    if (points.isEmpty) return;

    // Líneas de pared
    final wallPaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], wallPaint);
    }

    // Cerrar polígono si aplica
    if (isClosed && points.length >= 3) {
      final closePaint = Paint()
        ..color = Colors.greenAccent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(points.last, points.first, closePaint);
    }

    // Puntos (esquinas) — drawPoints es la API correcta de Canvas
    final pointPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    if (points.isNotEmpty) {
      canvas.drawPoints(PointMode.points, points, pointPaint);
    }

    // Punto activo (último)
    if (points.isNotEmpty) {
      final activePaint = Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      canvas.drawPoints(PointMode.points, [points.last], activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ManualFloorPlanPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.isClosed != isClosed;
  }
}

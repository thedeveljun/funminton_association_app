import 'package:flutter/material.dart';

class MiddleDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..strokeWidth = 4.0;

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    canvas.drawLine(
      Offset(0, y - 2.2),
      Offset(size.width, y - 2.2),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

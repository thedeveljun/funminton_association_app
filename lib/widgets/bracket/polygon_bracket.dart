// 배드민턴 대진표 — 다각형 풀리그 시각화
// (reference/bracket_reference.dart SECTION 3)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/bracket_models.dart';

/// 정N각형의 모든 정점에 팀을 배치하고 모든 정점을 선으로 연결.
/// 각 선이 하나의 경기 = N(N-1)/2 경기 자동 생성.
class PolygonBracket extends StatelessWidget {
  final int teams;
  final List<TeamData> teamData;
  final List<MatchInfo>? matches;

  const PolygonBracket({
    super.key,
    required this.teams,
    required this.teamData,
    this.matches,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.75,
      child: CustomPaint(
        painter: PolygonBracketPainter(
          teams: teams,
          teamData: teamData,
          matches: matches,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class PolygonBracketPainter extends CustomPainter {
  final int teams;
  final List<TeamData> teamData;
  final List<MatchInfo>? matches;

  PolygonBracketPainter({
    required this.teams,
    required this.teamData,
    this.matches,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    final r = math.min(size.width / 2, size.height / 2) * 0.6;
    final n = teams;
    final startAngle = -math.pi / 2; // 12시 방향에서 시작
    final step = 2 * math.pi / n;

    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final a = startAngle + i * step;
      points.add(Offset(cx + r * math.cos(a), cy + r * math.sin(a)));
    }

    final edgePaint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    int matchIdx = 0;
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        canvas.drawLine(points[i], points[j], edgePaint);

        if (n <= 6 && matches != null && matchIdx < matches!.length) {
          _drawMatchLabel(
            canvas,
            points[i],
            points[j],
            cx,
            cy,
            '${matches![matchIdx].court}코트',
          );
        }
        matchIdx++;
      }
    }

    final vertexPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..style = PaintingStyle.fill;

    for (final p in points) {
      canvas.drawCircle(p, 4.5, vertexPaint);
    }

    for (int i = 0; i < n; i++) {
      final a = startAngle + i * step;
      const labelDist = 38.0;
      final lx = cx + (r + labelDist) * math.cos(a);
      final ly = cy + (r + labelDist) * math.sin(a);

      final teamName =
          i < teamData.length ? teamData[i].name : '팀 ${i + 1}';
      final players = i < teamData.length
          ? teamData[i].players.join(' · ')
          : '선수 A · B';

      _drawLabel(canvas, lx, ly, teamName, players, math.cos(a));
    }
  }

  void _drawMatchLabel(
    Canvas canvas,
    Offset p1,
    Offset p2,
    double cx,
    double cy,
    String text,
  ) {
    final mx = (p1.dx + p2.dx) / 2;
    final my = (p1.dy + p2.dy) / 2;
    final dx = mx - cx;
    final dy = my - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    double ox = 0, oy = 0;
    if (dist > 4) {
      ox = (dx / dist) * 8;
      oy = (dy / dist) * 8;
    }

    final rect = Rect.fromCenter(
      center: Offset(mx + ox, my + oy),
      width: 36,
      height: 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = const Color(0xFFDC2626)
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFDC2626),
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(mx + ox - tp.width / 2, my + oy - tp.height / 2));
  }

  void _drawLabel(Canvas canvas, double lx, double ly, String name,
      String players, double cosA) {
    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFF1E3A8A),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final playersPainter = TextPainter(
      text: TextSpan(
        text: players,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double nameOffsetX = -namePainter.width / 2;
    double playersOffsetX = -playersPainter.width / 2;
    if (cosA > 0.3) {
      nameOffsetX = 0;
      playersOffsetX = 0;
    } else if (cosA < -0.3) {
      nameOffsetX = -namePainter.width;
      playersOffsetX = -playersPainter.width;
    }

    namePainter.paint(canvas, Offset(lx + nameOffsetX, ly - 8));
    playersPainter.paint(canvas, Offset(lx + playersOffsetX, ly + 6));
  }

  @override
  bool shouldRepaint(PolygonBracketPainter oldDelegate) {
    return oldDelegate.teams != teams || oldDelegate.matches != matches;
  }
}

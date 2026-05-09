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
  final Color? courtColor;

  const PolygonBracket({
    super.key,
    required this.teams,
    required this.teamData,
    this.matches,
    this.courtColor,
  });

  @override
  Widget build(BuildContext context) {
    // ClipRect 로 캔버스 밖 라벨이 인접 위젯 영역을 침범하지 않도록 차단.
    return AspectRatio(
      aspectRatio: 1.0,
      child: ClipRect(
        child: CustomPaint(
          painter: PolygonBracketPainter(
            teams: teams,
            teamData: teamData,
            matches: matches,
            courtColor: courtColor ?? const Color(0xFFDC2626),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class PolygonBracketPainter extends CustomPainter {
  final int teams;
  final List<TeamData> teamData;
  final List<MatchInfo>? matches;
  final Color courtColor;

  PolygonBracketPainter({
    required this.teams,
    required this.teamData,
    this.matches,
    this.courtColor = const Color(0xFFDC2626),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // 다각형 중심을 캔버스 가운데로 두고 반경을 줄여 라벨이 캔버스 안에 들어오게 한다.
    // 라벨은 정점에서 labelDist 만큼 더 바깥에 그려지므로 r 을 너무 키우면 잘림.
    final cy = size.height * 0.50;
    final r = math.min(size.width / 2, size.height / 2) * 0.50;
    final n = teams;
    // 4팀(정사각형)은 변이 수평/수직이 되도록 -45° 시작 (정점 = 1.5/4.5/7.5/10.5시).
    // 그 외 다각형은 12시 방향 정점에서 시작.
    final startAngle = n == 4 ? -math.pi / 4 : -math.pi / 2;
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

        // 외곽 변 = 인접 정점. 별모양 안쪽 변 = 대각선.
        final isOuterEdge = (j - i == 1) || (i == 0 && j == n - 1);
        // 모든 변 라벨 표시.
        final showLabel = matches != null && matchIdx < matches!.length;

        if (showLabel) {
          final m = matches![matchIdx];
          double t = 0.5;
          bool rotate = false;
          bool labelOffset = false; // 라벨을 변에서 외부 방향으로 떨어뜨릴지

          if (n == 4) {
            // 사각형 — 기존 동작 유지 (외곽 변은 회전 X, 대각선만 회전)
            if (i == 0 && j == 2) {
              t = 0.70;
              rotate = true;
            } else if (i == 1 && j == 3) {
              t = 0.70;
              rotate = true;
            }
          } else if (n >= 5) {
            // 오각형+ — 모든 변에 회전 라벨.
            rotate = true;
            if (isOuterEdge) {
              // 외곽 변: 변 옆에 라벨 (변 선이 라벨 중앙을 지나지 않음)
              t = 0.5;
              labelOffset = true;
            } else {
              // 별 안쪽 변: 정점 측으로 분산하여 캔버스 중앙 겹침 방지.
              // (j-i==2) 인 변은 작은 인덱스(p1) 측, (j-i==3) 인 변은 큰 인덱스(p2) 측.
              // 변 라인이 라벨 가운데를 통과(labelOffset 미적용).
              if (n == 5) {
                t = (j - i == 2) ? 0.30 : 0.70;
              } else {
                t = 0.35;
              }
            }
          }
          final p1 = points[i];
          final p2 = points[j];
          final mid = Offset(
            p1.dx * (1 - t) + p2.dx * t,
            p1.dy * (1 - t) + p2.dy * t,
          );
          double labelAngle = 0;
          if (rotate) {
            final ddx = p2.dx - p1.dx;
            final ddy = p2.dy - p1.dy;
            labelAngle = math.atan2(ddy, ddx);
            // 글자가 거꾸로 표시되지 않도록 (-π/2, +π/2) 범위로 정규화.
            if (labelAngle > math.pi / 2) labelAngle -= math.pi;
            if (labelAngle < -math.pi / 2) labelAngle += math.pi;
          }
          _drawMatchLabel(
            canvas,
            mid,
            cx,
            cy,
            '${m.court}코트 ${m.num_}',
            m.time,
            angle: labelAngle,
            outerOffset: n <= 4 ? 18 : 14,
            applyOffsetWhenRotated: labelOffset,
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
      const labelDist = 40.0;
      final lx = cx + (r + labelDist) * math.cos(a);
      final ly = cy + (r + labelDist) * math.sin(a);

      final teamName =
          i < teamData.length ? teamData[i].name : '';
      // 5팀에서 좌우 가장 튀어나온 정점(1=우상, 4=좌상)은 선수 이름을
      // 두 줄로 표시 → 화면 가장자리에서 한 줄이 폭 부족할 때 자연스러움.
      final isLateral = n == 5 && (i == 1 || i == 4);
      final players = i < teamData.length
          ? teamData[i].players.join(isLateral ? '\n' : ' · ')
          : '';

      _drawLabel(canvas, lx, ly, teamName, players,
          math.cos(a), math.sin(a), size);
    }
  }

  void _drawMatchLabel(
    Canvas canvas,
    Offset midpoint,
    double cx,
    double cy,
    String line1,
    String line2, {
    double angle = 0,
    double outerOffset = 22,
    bool applyOffsetWhenRotated = false,
  }) {
    // 박스 없는 두 줄 텍스트 라벨.
    // angle != 0: 변 방향에 맞춰 텍스트 회전.
    // applyOffsetWhenRotated: 회전된 라벨도 변에서 외부 방향으로 떨어뜨림
    //                        (오각형+ 외곽 변에만 사용 — 변 선이 라벨 중앙 안 지남).
    final mx = midpoint.dx;
    final my = midpoint.dy;
    final dx = mx - cx;
    final dy = my - cy;
    final dist = math.sqrt(dx * dx + dy * dy);
    double ox = 0, oy = 0;
    final shouldOffset = (angle == 0 || applyOffsetWhenRotated) && dist > 4;
    if (shouldOffset) {
      ox = (dx / dist) * outerOffset;
      oy = (dy / dist) * outerOffset;
    }

    final centerX = mx + ox;
    final centerY = my + oy;

    final tp1 = TextPainter(
      text: TextSpan(
        text: line1,
        style: TextStyle(
          color: courtColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tp2 = TextPainter(
      text: TextSpan(
        text: line2,
        style: const TextStyle(
          color: Color(0xFFDC2626),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final totalH = tp1.height + tp2.height + 1;

    if (angle != 0) {
      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(angle);
      tp1.paint(
        canvas,
        Offset(-tp1.width / 2, -totalH / 2),
      );
      tp2.paint(
        canvas,
        Offset(-tp2.width / 2, -totalH / 2 + tp1.height + 1),
      );
      canvas.restore();
    } else {
      final topY = centerY - totalH / 2;
      tp1.paint(
        canvas,
        Offset(centerX - tp1.width / 2, topY),
      );
      tp2.paint(
        canvas,
        Offset(centerX - tp2.width / 2, topY + tp1.height + 1),
      );
    }
  }

  void _drawLabel(Canvas canvas, double lx, double ly, String name,
      String players, double cosA, double sinA, Size canvasSize) {
    // 라벨 폭은 화면 폭의 45% 내에서 110~200px. 긴 이름도 가능한 한 잘리지 않게.
    // 그래도 길면 선수 이름은 두 줄까지 허용.
    final maxLabelWidth =
        (canvasSize.width * 0.45).clamp(110.0, 200.0);

    // 정점 위치에 따라 두 줄 정렬 결정.
    final TextAlign nameAlign = cosA > 0.3
        ? TextAlign.right
        : (cosA < -0.3 ? TextAlign.left : TextAlign.center);

    // 윗줄: 선수 이름 (메인) — 진하게. 두 줄일 때도 정점 방향 정렬.
    final playersPainter = TextPainter(
      text: TextSpan(
        text: players,
        style: const TextStyle(
          color: Color(0xFF1E3A8A),
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: nameAlign,
      maxLines: 2,
      ellipsis: '…',
    )..layout(
        minWidth: nameAlign == TextAlign.left ? 0 : maxLabelWidth,
        maxWidth: maxLabelWidth,
      );

    // 아랫줄: 클럽명 — 약하게. 두 클럽이면 \n 포함 두 줄.
    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: nameAlign,
      maxLines: 2,
      ellipsis: '…',
    )..layout(
        // textAlign 효과를 보장하기 위해 painter 폭을 maxLabelWidth 로 강제.
        // 짧은 줄도 같은 폭 안에서 좌/우/중앙 정렬됨.
        minWidth: nameAlign == TextAlign.center ? 0 : maxLabelWidth,
        maxWidth: maxLabelWidth,
      );

    // 좌/우/중앙 정렬을 cosA 부호로 결정
    double nameX, playersX;
    if (cosA > 0.3) {
      nameX = lx;
      playersX = lx;
    } else if (cosA < -0.3) {
      nameX = lx - namePainter.width;
      playersX = lx - playersPainter.width;
    } else {
      nameX = lx - namePainter.width / 2;
      playersX = lx - playersPainter.width / 2;
    }

    // 화면 가로 안으로 clamp (4px 마진).
    final maxNameX = (canvasSize.width - 4 - namePainter.width).clamp(
      0.0,
      canvasSize.width,
    );
    final maxPlayersX = (canvasSize.width - 4 - playersPainter.width).clamp(
      0.0,
      canvasSize.width,
    );
    nameX = nameX.clamp(4.0, maxNameX);
    playersX = playersX.clamp(4.0, maxPlayersX);

    // 정점에서 먼 쪽에 메인(선수 이름) 배치 — 시각적으로 정점이 클럽명을 가리킴.
    // - 위쪽 정점(sinA <= 0): 선수가 라벨 위, 클럽이 라벨 아래
    // - 아래쪽 정점(sinA > 0): 클럽이 라벨 위, 선수가 라벨 아래
    final lowerVertex = sinA > 0;
    if (lowerVertex) {
      namePainter.paint(canvas, Offset(nameX, ly - namePainter.height));
      playersPainter.paint(canvas, Offset(playersX, ly + 1));
    } else {
      playersPainter.paint(
        canvas,
        Offset(playersX, ly - playersPainter.height),
      );
      namePainter.paint(canvas, Offset(nameX, ly + 1));
    }
  }

  @override
  bool shouldRepaint(PolygonBracketPainter oldDelegate) {
    return oldDelegate.teams != teams || oldDelegate.matches != matches;
  }
}

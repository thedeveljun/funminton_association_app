// 배드민턴 대진표 — 토너먼트 브래킷 시각화
// (reference/bracket_reference.dart SECTION 4)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/bracket_models.dart';

class TournamentBracket extends StatelessWidget {
  final int size;
  final List<TeamData>? seedTeams;

  const TournamentBracket({
    super.key,
    required this.size,
    this.seedTeams,
  });

  @override
  Widget build(BuildContext context) {
    final rounds = (math.log(size) / math.log(2)).ceil();
    final slotCount = math.pow(2, rounds).toInt();

    return SizedBox(
      height: slotCount * 35.0 + 30,
      child: CustomPaint(
        painter: TournamentBracketPainter(
          rounds: rounds,
          slotCount: slotCount,
          actualTeams: size,
          seedTeams: seedTeams,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class TournamentBracketPainter extends CustomPainter {
  final int rounds;
  final int slotCount;
  final int actualTeams;
  final List<TeamData>? seedTeams;

  TournamentBracketPainter({
    required this.rounds,
    required this.slotCount,
    required this.actualTeams,
    this.seedTeams,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final colWidth = size.width / (rounds + 1);
    final usableHeight = size.height - 20;

    final slots = <_BracketSlot>[];
    for (int r = 0; r <= rounds; r++) {
      final slotsInRound = slotCount ~/ math.pow(2, r).toInt();
      final spacing = usableHeight / slotsInRound;
      for (int s = 0; s < slotsInRound; s++) {
        slots.add(_BracketSlot(
          round: r,
          slot: s,
          x: r * colWidth + 5,
          y: spacing * s + spacing / 2 - 12,
          width: colWidth - 14,
        ));
      }
    }

    for (final s in slots.where((s) => s.round < rounds)) {
      final isFirst = s.round == 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.x, s.y, s.width, 24),
          const Radius.circular(3),
        ),
        Paint()
          ..color = isFirst
              ? const Color(0xFFDBEAFE)
              : const Color(0xFFF3F4F6)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.x, s.y, s.width, 24),
          const Radius.circular(3),
        ),
        Paint()
          ..color = isFirst
              ? const Color(0xFF1E3A8A)
              : const Color(0xFFD1D5DB)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke,
      );

      if (isFirst) {
        String label;
        if (s.slot < actualTeams) {
          label = seedTeams != null && s.slot < seedTeams!.length
              ? seedTeams![s.slot].name
              : '시드 ${s.slot + 1}';
        } else {
          label = '부전승';
        }
        if (label.length > 8) label = '${label.substring(0, 8)}..';

        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF1E3A8A),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(s.x + 6, s.y + 7));
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    for (final s in slots) {
      if (s.round == 0) continue;
      if (s.round == rounds) {
        // 우승 슬롯 — 결승 슬롯(round-1, slot=0) 에서 라인 1개
        final c = slots
            .where((c) => c.round == rounds - 1 && c.slot == 0)
            .toList();
        if (c.isEmpty) continue;
        canvas.drawLine(
          Offset(c.first.x + c.first.width, c.first.y + 12),
          Offset(s.x, s.y + 12),
          linePaint,
        );
        continue;
      }
      final c1 = slots.where((c) =>
          c.round == s.round - 1 && c.slot == s.slot * 2).toList();
      final c2 = slots.where((c) =>
          c.round == s.round - 1 && c.slot == s.slot * 2 + 1).toList();
      if (c1.isEmpty || c2.isEmpty) continue;

      canvas.drawLine(
        Offset(c1.first.x + c1.first.width, c1.first.y + 12),
        Offset(s.x, s.y + 12),
        linePaint,
      );
      canvas.drawLine(
        Offset(c2.first.x + c2.first.width, c2.first.y + 12),
        Offset(s.x, s.y + 12),
        linePaint,
      );
    }

    // 우승 슬롯 — 골드 박스 + '우승' 라벨
    final winnerSlots = slots.where((s) => s.round == rounds).toList();
    if (winnerSlots.isNotEmpty) {
      final w = winnerSlots.first;
      final winnerRect = Rect.fromLTWH(w.x, w.y, w.width, 24);
      canvas.drawRRect(
        RRect.fromRectAndRadius(winnerRect, const Radius.circular(3)),
        Paint()
          ..color = const Color(0xFFFEF3C7)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(winnerRect, const Radius.circular(3)),
        Paint()
          ..color = const Color(0xFFD97706)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
      final wp = TextPainter(
        text: const TextSpan(
          text: '우승',
          style: TextStyle(
            color: Color(0xFF92400E),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      wp.paint(canvas, Offset(w.x + 6, w.y + 6));
    }

    final tp = TextPainter(
      text: const TextSpan(
        text: '예선 1위 성적순으로 부전승 자리 배치',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(5, size.height - 14));
  }

  @override
  bool shouldRepaint(TournamentBracketPainter oldDelegate) {
    return oldDelegate.actualTeams != actualTeams ||
        oldDelegate.rounds != rounds;
  }
}

class _BracketSlot {
  final int round;
  final int slot;
  final double x;
  final double y;
  final double width;

  _BracketSlot({
    required this.round,
    required this.slot,
    required this.x,
    required this.y,
    required this.width,
  });
}

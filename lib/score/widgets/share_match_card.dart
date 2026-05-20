import 'package:flutter/material.dart';
import 'package:badminton_association/score/l10n/app_strings.dart';
import 'package:badminton_association/score/models/saved_match_record.dart';

class ShareMatchCard extends StatelessWidget {
  final SavedMatchRecord record;
  final S s;

  const ShareMatchCard({super.key, required this.record, required this.s});

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftWin = record.scoreA > record.scoreB;
    final rightWin = record.scoreB > record.scoreA;

    final leftLine =
        '${s.localizedPlayerName(record.leftPlayer1)}\n${s.localizedPlayerName(record.leftPlayer2)}';
    final rightLine =
        '${s.localizedPlayerName(record.rightPlayer1)}\n${s.localizedPlayerName(record.rightPlayer2)}';

    return Material(
      color: Colors.white,
      child: Container(
        width: 1080,
        height: 1080,
        padding: const EdgeInsets.fromLTRB(60, 72, 60, 72),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEFF1FF), Color(0xFFF8FAFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더: 타이틀 + 날짜
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 120,
                      child: Text('🏸',
                          style: TextStyle(fontSize: 84, height: 1)),
                    ),
                    Flexible(
                      child: Text(
                        s.shareSubject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A0954),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.only(left: 120),
                  child: Text(
                    _formatDate(record.savedAt),
                    style: const TextStyle(
                      fontSize: 52,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (record.contextLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 120),
                    child: Text(
                      record.contextLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 40,
                        color: Color(0xFF3730A3),
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 64),

            // 점수 카드
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(56),
                border: Border.all(color: const Color(0xFFE4E7EB), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _teamSide(
                      label: leftLine,
                      score: record.scoreA,
                      isWinner: leftWin,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'vs',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _teamSide(
                      label: rightLine,
                      score: record.scoreB,
                      isWinner: rightWin,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamSide({
    required String label,
    required int score,
    required bool isWinner,
  }) {
    final color = isWinner ? const Color(0xFF1565C0) : Colors.black87;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: color,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '$score',
          style: TextStyle(
            fontSize: 220,
            fontWeight: FontWeight.w800,
            height: 1,
            color: color,
          ),
        ),
        if (isWinner) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              s.win,
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

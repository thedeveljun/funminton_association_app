import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/match_score.dart';
import '../../models/tournament.dart';

/// 대회 마감용 — 서명이 등록된 매치들을 한 화면에 일괄 조회.
///
/// BracketScreen 의 운영 메뉴에서 진입. 부모가 [matchScores] 와 [tournament] 를
/// 넘겨주면 이 페이지는 winnerSignature 가 비어있지 않은 항목만 추출해서 정렬·표시한다.
/// 라이브 stream 구독은 부모에 두고 여기는 스냅샷만 보여줘서 의존 단순화.
class SignaturesPage extends StatelessWidget {
  final Tournament tournament;
  final Map<String, MatchScore> matchScores;

  const SignaturesPage({
    super.key,
    required this.tournament,
    required this.matchScores,
  });

  @override
  Widget build(BuildContext context) {
    final entries = _signedEntries();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('서명 모음 · ${entries.length}건',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.text)),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '서명이 등록된 매치가 없습니다.\n점수 입력 후 승자팀 서명을 받으면 여기에 모입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SignedMatchCard(score: entries[i]),
            ),
    );
  }

  /// winnerSignature 가 등록된 매치만 추출 후 키 문자열 정렬.
  /// 키 포맷: `event|age|grade|group|matchNum` — 그대로 사전순 정렬해도
  /// (event → age → grade → group → 매치번호) 순서로 자연스럽게 정렬됨.
  /// 단 matchNum 은 숫자 비교가 필요해 분리 정렬.
  List<MatchScore> _signedEntries() {
    final list = matchScores.values
        .where((m) => m.winnerSignature.isNotEmpty)
        .toList();
    list.sort((a, b) {
      final pa = a.key.split('|');
      final pb = b.key.split('|');
      for (var i = 0; i < 4 && i < pa.length && i < pb.length; i++) {
        final cmp = pa[i].compareTo(pb[i]);
        if (cmp != 0) return cmp;
      }
      final na = int.tryParse(pa.length > 4 ? pa[4] : '') ?? 0;
      final nb = int.tryParse(pb.length > 4 ? pb[4] : '') ?? 0;
      return na.compareTo(nb);
    });
    return list;
  }
}

class _SignedMatchCard extends StatelessWidget {
  final MatchScore score;
  const _SignedMatchCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final parts = score.key.split('|');
    final event = parts.isNotEmpty ? parts[0] : '';
    final age = parts.length > 1 ? parts[1] : '';
    final grade = parts.length > 2 ? parts[2] : '';
    final group = parts.length > 3 ? parts[3] : '';
    final num = parts.length > 4 ? parts[4] : '';
    final headerBits = <String>[
      if (event.isNotEmpty) event,
      if (age.isNotEmpty) '$age대',
      if (grade.isNotEmpty) grade,
      if (group.isNotEmpty) group,
      if (num.isNotEmpty) 'M$num',
    ];
    final winnerNames = score.winnerSide == 'A'
        ? score.teamANames
        : score.winnerSide == 'B'
            ? score.teamBNames
            : const <String>[];
    final signatureBytes = _decodeDataUrl(score.winnerSignature);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headerBits.join(' · '),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted)),
          const SizedBox(height: 6),
          _TeamLine(
              names: score.teamANames,
              score: score.scoreA,
              isWinner: score.winnerSide == 'A'),
          const SizedBox(height: 3),
          _TeamLine(
              names: score.teamBNames,
              score: score.scoreB,
              isWinner: score.winnerSide == 'B'),
          const SizedBox(height: 10),
          if (winnerNames.isNotEmpty)
            Text('승자: ${winnerNames.join(', ')}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryMid)),
          const SizedBox(height: 6),
          if (signatureBytes != null)
            Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.all(6),
              child: Image.memory(
                signatureBytes,
                fit: BoxFit.contain,
                height: 80,
                gaplessPlayback: true,
              ),
            )
          else
            const Text('(서명 이미지 파싱 실패)',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }

  /// `data:image/png;base64,...` data URL → 바이트. 형식이 다르면 null.
  static Uint8List? _decodeDataUrl(String url) {
    final idx = url.indexOf('base64,');
    if (idx < 0) return null;
    final b64 = url.substring(idx + 'base64,'.length);
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }
}

class _TeamLine extends StatelessWidget {
  final List<String> names;
  final int score;
  final bool isWinner;
  const _TeamLine({
    required this.names,
    required this.score,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    final text = names.isEmpty ? '(팀 정보 없음)' : names.join(', ');
    return Row(
      children: [
        Icon(
          isWinner ? Icons.emoji_events : Icons.circle_outlined,
          size: 14,
          color: isWinner ? AppColors.primaryMid : AppColors.muted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
              color: isWinner ? AppColors.text : AppColors.muted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text('$score',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isWinner ? AppColors.primaryMid : AppColors.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
      ],
    );
  }
}

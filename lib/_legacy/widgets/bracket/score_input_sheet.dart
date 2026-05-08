import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/match.dart';

class ScoreInputSheet extends StatefulWidget {
  final Match match;
  final Future<void> Function(int scoreA, int scoreB) onSave;

  const ScoreInputSheet({super.key, required this.match, required this.onSave});

  static Future<void> show(
    BuildContext context,
    Match match,
    Future<void> Function(int, int) onSave,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScoreInputSheet(match: match, onSave: onSave),
    );
  }

  @override
  State<ScoreInputSheet> createState() => _ScoreInputSheetState();
}

class _ScoreInputSheetState extends State<ScoreInputSheet> {
  late int _sA;
  late int _sB;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sA = widget.match.scoreA ?? 0;
    _sB = widget.match.scoreB ?? 0;
  }

  String get _winnerText {
    if (_sA > _sB) return '${widget.match.teamANames} (A팀 승)';
    if (_sB > _sA) return '${widget.match.teamBNames} (B팀 승)';
    if (_sA > 0) return '동점';
    return '미정';
  }

  Color get _winnerColor {
    if (_sA == _sB && _sA == 0) return AppColors.muted;
    if (_sA == _sB) return AppColors.amber;
    return AppColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 핸들
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.gray2,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        // 타이틀
        Text(widget.match.courtLabel,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.text)),
        const SizedBox(height: 2),
        Text('${widget.match.type.label} · ${widget.match.day}일차',
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 18),
        // A팀
        _ScoreRow(
          teamLabel: 'A팀',
          playerNames: widget.match.teamA
              .map((p) => '${p.name}(${p.grade})')
              .join(' / '),
          score: _sA,
          onDec: () {
            if (_sA > 0) setState(() => _sA--);
          },
          onInc: () => setState(() => _sA++),
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n >= 0) setState(() => _sA = n);
          },
        ),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('VS',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted))),
        // B팀
        _ScoreRow(
          teamLabel: 'B팀',
          playerNames: widget.match.teamB
              .map((p) => '${p.name}(${p.grade})')
              .join(' / '),
          score: _sB,
          onDec: () {
            if (_sB > 0) setState(() => _sB--);
          },
          onInc: () => setState(() => _sB++),
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n >= 0) setState(() => _sB = n);
          },
        ),
        const SizedBox(height: 14),
        // 승자 표시
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
              color: AppColors.gray, borderRadius: BorderRadius.circular(10)),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('승리팀',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            Text(_winnerText,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _winnerColor)),
          ]),
        ),
        const SizedBox(height: 14),
        // 저장
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await widget.onSave(_sA, _sB);
                    if (mounted) Navigator.pop(context);
                  },
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('저장'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppColors.text2)),
          ),
        ),
      ]),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String teamLabel;
  final String playerNames;
  final int score;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final ValueChanged<String> onChanged;

  const _ScoreRow({
    required this.teamLabel,
    required this.playerNames,
    required this.score,
    required this.onDec,
    required this.onInc,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(teamLabel,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(height: 2),
          Text(playerNames,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
              overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        // − 버튼
        GestureDetector(
          onTap: onDec,
          child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                  color: AppColors.gray2, shape: BoxShape.circle),
              child: const Center(
                  child: Icon(Icons.remove, size: 18, color: AppColors.text2))),
        ),
        const SizedBox(width: 8),
        // 점수 입력
        Container(
          width: 50,
          height: 40,
          decoration: BoxDecoration(
              border: Border.all(color: AppColors.gray2),
              borderRadius: BorderRadius.circular(9)),
          child: TextFormField(
            initialValue: '$score',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text),
            decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        // + 버튼
        GestureDetector(
          onTap: onInc,
          child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                  color: AppColors.gray2, shape: BoxShape.circle),
              child: const Center(
                  child: Icon(Icons.add, size: 18, color: AppColors.text2))),
        ),
      ]);
}

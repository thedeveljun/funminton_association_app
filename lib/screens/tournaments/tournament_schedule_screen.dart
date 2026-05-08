import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/scheduled_tournament.dart';
import '../../services/sample_data.dart';

/// 대회 일정 — 협회가 주관하지 않지만 일정상 참가/참고해야 할 외부 대회를 관리.
/// 예: '생활대축전배드민턴대회' 처럼 시도협회 주관이 아닌 전국 단위 대회.
/// '대회운영' 화면과는 완전히 별개의 데이터 (ScheduledTournament).
class TournamentScheduleScreen extends StatefulWidget {
  const TournamentScheduleScreen({super.key});

  @override
  State<TournamentScheduleScreen> createState() =>
      _TournamentScheduleScreenState();
}

class _TournamentScheduleScreenState extends State<TournamentScheduleScreen> {
  List<ScheduledTournament> get _items {
    final list = [...SampleData.scheduledTournaments]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return list;
  }

  Future<void> _persist() => SampleData.saveScheduledTournaments();

  Future<void> _add() async {
    final created = await _showFormSheet();
    if (created == null) return;
    setState(() => SampleData.scheduledTournaments.add(created));
    await _persist();
  }

  Future<void> _edit(ScheduledTournament t) async {
    final updated = await _showFormSheet(initial: t);
    if (updated == null) return;
    final idx =
        SampleData.scheduledTournaments.indexWhere((s) => s.id == t.id);
    if (idx < 0) return;
    setState(() => SampleData.scheduledTournaments[idx] = updated);
    await _persist();
  }

  Future<void> _delete(ScheduledTournament t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${t.name} 삭제'),
        content: const Text('이 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() =>
        SampleData.scheduledTournaments.removeWhere((s) => s.id == t.id));
    await _persist();
  }

  Future<ScheduledTournament?> _showFormSheet(
      {ScheduledTournament? initial}) async {
    return showModalBottomSheet<ScheduledTournament>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ScheduleForm(initial: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    // 연도 → 월 → 대회목록
    final byYearMonth = <String, Map<String, List<ScheduledTournament>>>{};
    for (final t in items) {
      final ym = _parseYearMonth(t.startDate);
      if (ym == null) continue;
      final yKey = ym.$1.toString();
      final mKey = ym.$2.toString().padLeft(2, '0');
      byYearMonth
          .putIfAbsent(yKey, () => {})
          .putIfAbsent(mKey, () => [])
          .add(t);
    }
    final yearKeys = byYearMonth.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          '대회 일정',
          style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add,
                size: 18, color: AppColors.primaryMid),
            label: const Text('일정',
                style: TextStyle(
                    color: AppColors.primaryMid,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '등록된 외부 대회 일정이 없습니다.\n우측 상단 [+ 일정] 버튼으로 추가하세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                14,
                12,
                14,
                20 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                for (final y in yearKeys) ...[
                  _YearHeader(
                    year: y,
                    count: byYearMonth[y]!
                        .values
                        .fold<int>(0, (s, l) => s + l.length),
                  ),
                  for (final m
                      in (byYearMonth[y]!.keys.toList()..sort()))
                    _MonthBlock(
                      month: m,
                      tournaments: byYearMonth[y]![m]!,
                      onTap: _edit,
                      onDelete: _delete,
                    ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
    );
  }

  static (int, int)? _parseYearMonth(String date) {
    final parts = date.split('-');
    if (parts.length < 2) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return null;
    return (y, m);
  }
}

class _YearHeader extends StatelessWidget {
  final String year;
  final int count;
  const _YearHeader({required this.year, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
        child: Row(children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              color: AppColors.primaryMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text('$year년',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const SizedBox(width: 8),
          Text('$count건',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text2)),
        ]),
      );
}

class _MonthBlock extends StatelessWidget {
  final String month;
  final List<ScheduledTournament> tournaments;
  final ValueChanged<ScheduledTournament> onTap;
  final ValueChanged<ScheduledTournament> onDelete;

  const _MonthBlock({
    required this.month,
    required this.tournaments,
    required this.onTap,
    required this.onDelete,
  });

  /// 월별 파스텔 보더 — 1월~12월 각각 다른 톤.
  /// 카드 보더 톤(_pastelBorder, tournament_list_screen)과 비슷한 채도/명도.
  static const Map<int, Color> _monthBorder = {
    1: Color(0xFFF8B6C5), // 핑크
    2: Color(0xFFC9B8E8), // 라일락
    3: Color(0xFFB8D8F0), // 스카이블루
    4: Color(0xFFB8E5D0), // 민트
    5: Color(0xFFF0E0A8), // 옐로
    6: Color(0xFFF4C0A8), // 코럴
    7: Color(0xFFD5E8B0), // 라임
    8: Color(0xFFA8DDDD), // 틸
    9: Color(0xFFD5C4E8), // 라벤더
    10: Color(0xFFF8D4A8), // 살구
    11: Color(0xFFE8C0C0), // 더스티 로즈
    12: Color(0xFFB8C4DC), // 블루그레이
  };

  Color _borderFor(int m) =>
      _monthBorder[m] ?? const Color(0xFFD8DEE8);

  @override
  Widget build(BuildContext context) {
    final m = int.parse(month);
    final border = _borderFor(m);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 2.5),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 4),
          decoration: BoxDecoration(
            color: border.withOpacity(0.85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(9.5),
              topRight: Radius.circular(9.5),
            ),
            border: Border(
              bottom: BorderSide(color: border, width: 1.5),
            ),
          ),
          child: Row(children: [
            Text('$m월',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(width: 6),
            Text('· ${tournaments.length}건',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text2)),
          ]),
        ),
        ...tournaments.map((t) => _ScheduleRow(
              tournament: t,
              onTap: () => onTap(t),
              onDelete: () => onDelete(t),
            )),
      ]),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final ScheduledTournament tournament;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ScheduleRow({
    required this.tournament,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return InkWell(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.divider, width: .5)),
        ),
        child: Row(children: [
          // 좌측 일자
          SizedBox(
            width: 56,
            child: Text(_dayRange(t.startDate, t.endDate),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text)),
                if (t.host.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _MetaLine(label: '주최', value: t.host),
                ],
                if (t.location.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  _MetaLine(label: '장소', value: t.location),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _AttendPill(attending: t.attending),
        ]),
      ),
    );
  }

  String _dayRange(String start, String end) {
    final s = _parseDay(start);
    final e = _parseDay(end);
    if (s == null) return '-';
    if (end.isEmpty || e == null || e == s) {
      return s.toString().padLeft(2, '0');
    }
    return '${s.toString().padLeft(2, '0')}–${e.toString().padLeft(2, '0')}';
  }

  static int? _parseDay(String date) {
    final parts = date.split('-');
    if (parts.length < 3) return null;
    return int.tryParse(parts[2]);
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;
  const _MetaLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
          ),
          Expanded(
            child: Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.text2,
                    height: 1.25)),
          ),
        ],
      );
}

class _AttendPill extends StatelessWidget {
  final bool attending;
  const _AttendPill({required this.attending});

  @override
  Widget build(BuildContext context) {
    final bg = attending
        ? const Color(0xFFDDF5E8)
        : const Color(0xFFE2E8F0);
    final fg = attending
        ? const Color(0xFF16794D)
        : const Color(0xFF475569);
    final label = attending ? '참가 예정' : '미정';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  추가/수정 폼 (BottomSheet)
// ═══════════════════════════════════════════════════════
class _ScheduleForm extends StatefulWidget {
  final ScheduledTournament? initial;
  const _ScheduleForm({this.initial});

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _locCtrl;
  late final TextEditingController _memoCtrl;
  String _start = '';
  String _end = '';
  bool _attending = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _hostCtrl = TextEditingController(text: t?.host ?? '');
    _locCtrl = TextEditingController(text: t?.location ?? '');
    _memoCtrl = TextEditingController(text: t?.memo ?? '');
    _start = t?.startDate ?? '';
    _end = t?.endDate ?? '';
    _attending = t?.attending ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _locCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = DateTime.tryParse(isStart ? _start : _end) ??
        DateTime.tryParse(_start) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    final s =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _start = s;
      } else {
        _end = s;
      }
    });
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('대회명을 입력하세요.')));
      return;
    }
    if (_start.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('시작일을 선택하세요.')));
      return;
    }
    final id = widget.initial?.id ??
        's_${DateTime.now().millisecondsSinceEpoch}';
    final result = ScheduledTournament(
      id: id,
      name: _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      location: _locCtrl.text.trim(),
      startDate: _start,
      endDate: _end.isEmpty ? _start : _end,
      attending: _attending,
      memo: _memoCtrl.text.trim(),
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // 키보드가 올라오면 viewInsets.bottom, 그 외에는 시스템 제스처 바 영역(padding.bottom)
    // 둘 중 큰 값으로 잡아 폼이 겹치지 않게 한다.
    final bottomInset = mq.viewInsets.bottom > 0
        ? mq.viewInsets.bottom
        : mq.padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_isEdit ? '대회 일정 수정' : '대회 일정 추가',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 12),
            _label('대회명'),
            _field(_nameCtrl,
                hint: '예: 2026 생활대축전 배드민턴대회',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _label('주최'),
            _field(_hostCtrl, hint: '예: 한국배드민턴협회'),
            const SizedBox(height: 8),
            _label('장소'),
            _field(_locCtrl, hint: '예: 한국시 / 한국시민체육관'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('시작일'),
                      _dateBtn(_start, () => _pickDate(true)),
                    ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('종료일'),
                      _dateBtn(_end, () => _pickDate(false)),
                    ]),
              ),
            ]),
            const SizedBox(height: 10),
            _label('참가 여부'),
            Row(children: [
              Expanded(child: _attendChoice(true, '경기예정')),
              const SizedBox(width: 8),
              Expanded(child: _attendChoice(false, '미정')),
            ]),
            const SizedBox(height: 4),
            _label('메모'),
            _field(_memoCtrl, hint: '비고/안내사항', maxLines: 2),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMid,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(_isEdit ? '저장' : '추가'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // 대회운영(_field) 라벨 스타일과 동일: 13px / w700 / text2
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text2)),
      );

  // 대회운영(대회등록) 폼의 _f / _denseInputDecoration 와 동일한 크기·테두리·텍스트 스타일.
  // 보더/색상은 글로벌 InputDecorationTheme 에서 상속.
  Widget _field(TextEditingController c,
          {String? hint, int maxLines = 1, TextStyle? style}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        style: style,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );

  Widget _attendChoice(bool value, String label) {
    final selected = _attending == value;
    final bg = selected
        ? (value ? const Color(0xFFDDF5E8) : const Color(0xFFE2E8F0))
        : Colors.white;
    final fg = selected
        ? (value ? const Color(0xFF16794D) : const Color(0xFF475569))
        : const Color(0xFFAAAAAA);
    final borderColor = selected
        ? (value ? const Color(0xFF16794D) : const Color(0xFF475569))
        : const Color(0xFFD8DEE8);
    return GestureDetector(
      onTap: () => setState(() => _attending = value),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg)),
      ),
    );
  }

  Widget _dateBtn(String value, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD8DEE8)),
          ),
          child: Row(children: [
            Text(value.isEmpty ? 'YYYY-MM-DD' : value,
                style: TextStyle(
                  fontSize: 14,
                  color: value.isEmpty
                      ? const Color(0xFFAAAAAA)
                      : AppColors.text,
                )),
            const Spacer(),
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.muted),
          ]),
        ),
      );
}

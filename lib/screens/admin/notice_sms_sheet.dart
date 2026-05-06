import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../models/admin_records.dart';
import '../../models/club.dart';
import '../../services/sample_data.dart';

/// 공지사항을 클럽 회장/총무 전화번호로 SMS 발송.
/// 단말의 기본 메시지 앱이 열리며, 받는사람과 본문이 자동 채워진다.
class NoticeSmsSheet extends StatefulWidget {
  final Notice notice;
  const NoticeSmsSheet({super.key, required this.notice});

  @override
  State<NoticeSmsSheet> createState() => _NoticeSmsSheetState();
}

class _NoticeSmsSheetState extends State<NoticeSmsSheet> {
  // clubId → (회장선택, 총무선택)
  final Map<String, _Selection> _sel = {};

  @override
  void initState() {
    super.initState();
    for (final c in SampleData.clubs) {
      _sel[c.id] = _Selection(
        president: c.presidentPhone.isNotEmpty,
        secretary: c.secretaryPhone.isNotEmpty,
      );
    }
  }

  List<String> _collectPhones() {
    final phones = <String>[];
    for (final c in SampleData.clubs) {
      final s = _sel[c.id];
      if (s == null) continue;
      if (s.president && c.presidentPhone.isNotEmpty) {
        phones.add(_normalize(c.presidentPhone));
      }
      if (s.secretary && c.secretaryPhone.isNotEmpty) {
        phones.add(_normalize(c.secretaryPhone));
      }
    }
    final unique = <String>{};
    return phones.where(unique.add).toList();
  }

  String _normalize(String p) => p.replaceAll(RegExp(r'[^\d+]'), '');

  String _buildBody() {
    final n = widget.notice;
    final buf = StringBuffer();
    buf.writeln('[공지] ${n.title}');
    if (n.date.isNotEmpty) buf.writeln(n.date);
    if (n.content.isNotEmpty) {
      buf.writeln();
      buf.writeln(n.content);
    }
    return buf.toString().trim();
  }

  Future<void> _send() async {
    final phones = _collectPhones();
    if (phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('받는 사람을 한 명 이상 선택하세요.')),
      );
      return;
    }
    // smsto: 와 sms: 둘 다 시도. 안드로이드는 smsto:가 더 잘 호환됨.
    final body = Uri.encodeComponent(_buildBody());
    final joined = phones.join(',');
    final candidates = [
      Uri.parse('sms:$joined?body=$body'),
      Uri.parse('smsto:$joined?body=$body'),
    ];
    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) {
            if (mounted) Navigator.pop(context);
            return;
          }
        }
      } catch (_) {/* try next */}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메시지 앱을 열 수 없습니다.')),
      );
    }
  }

  void _setAll({required bool president, required bool secretary}) {
    setState(() {
      for (final c in SampleData.clubs) {
        final s = _sel[c.id]!;
        if (president) s.president = c.presidentPhone.isNotEmpty;
        if (secretary) s.secretary = c.secretaryPhone.isNotEmpty;
      }
    });
  }

  void _clearAll() {
    setState(() {
      for (final s in _sel.values) {
        s.president = false;
        s.secretary = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final clubs = SampleData.clubs;
    final selectedCount = _collectPhones().length;
    final body = _buildBody();

    return Padding(
      padding:
          EdgeInsets.only(bottom: 16 + mq.viewInsets.bottom + mq.padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('공지 SMS 발송',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
            ),
          ),
          const SizedBox(height: 8),
          // 미리보기
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(body,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.text2,
                      height: 1.35)),
            ),
          ),
          const SizedBox(height: 10),
          // 일괄 선택 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: _quickBtn('회장 전체',
                    () => _setAll(president: true, secretary: false)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _quickBtn('총무 전체',
                    () => _setAll(president: false, secretary: true)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _quickBtn('전체',
                    () => _setAll(president: true, secretary: true)),
              ),
              const SizedBox(width: 6),
              Expanded(child: _quickBtn('해제', _clearAll)),
            ]),
          ),
          const SizedBox(height: 8),
          // 클럽 목록
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: clubs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) => _clubRow(clubs[i]),
            ),
          ),
          const SizedBox(height: 10),
          // 발송 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
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
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: selectedCount == 0 ? null : _send,
                  icon: const Icon(Icons.sms_rounded, size: 18),
                  label: Text('SMS 보내기 ($selectedCount명)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMid,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _quickBtn(String label, VoidCallback onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text2)),
      );

  Widget _clubRow(Club c) {
    final s = _sel[c.id]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
        ),
        Expanded(
          flex: 4,
          child: Row(children: [
            Expanded(
              child: _personChip(
                role: '회장',
                name: c.presidentName,
                phone: c.presidentPhone,
                selected: s.president,
                onChanged: (v) => setState(() => s.president = v),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _personChip(
                role: '총무',
                name: c.secretaryName,
                phone: c.secretaryPhone,
                selected: s.secretary,
                onChanged: (v) => setState(() => s.secretary = v),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _personChip({
    required String role,
    required String name,
    required String phone,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    final hasPhone = phone.isNotEmpty;
    final bg = !hasPhone
        ? const Color(0xFFF3F4F6)
        : (selected ? const Color(0xFFDDF5E8) : Colors.white);
    final borderColor = !hasPhone
        ? const Color(0xFFE5E7EB)
        : (selected
            ? const Color(0xFF16794D)
            : const Color(0xFFD8DEE8));
    final fg = !hasPhone
        ? const Color(0xFFAAAAAA)
        : (selected
            ? const Color(0xFF16794D)
            : AppColors.text2);
    return GestureDetector(
      onTap: hasPhone ? () => onChanged(!selected) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: borderColor, width: selected && hasPhone ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(role,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: fg)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(name.isEmpty ? '-' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: fg)),
              ),
              if (hasPhone)
                Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 14,
                  color: fg,
                ),
            ]),
            Text(
              hasPhone ? phone : '번호 없음',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _Selection {
  bool president;
  bool secretary;
  _Selection({required this.president, required this.secretary});
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/club.dart';
import '../../models/player.dart';
import '../../services/sample_data.dart';
import '../../widgets/common/form_action_bar.dart';

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > 11 ? digits.substring(0, 11) : digits;
    String formatted;
    if (trimmed.length <= 3) {
      formatted = trimmed;
    } else if (trimmed.length <= 7) {
      formatted = '${trimmed.substring(0, 3)}-${trimmed.substring(3)}';
    } else {
      formatted =
          '${trimmed.substring(0, 3)}-${trimmed.substring(3, 7)}-${trimmed.substring(7)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PlayerFormScreen extends StatefulWidget {
  final Player? initial; // null이면 등록, 값이 있으면 수정
  const PlayerFormScreen({super.key, this.initial});

  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _birthCtrl;
  late final TextEditingController _phoneCtrl;

  late String _gender;
  late String _grade;
  String? _selectedClubId;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _birthCtrl = TextEditingController(text: p?.birthDate ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _gender = p?.gender ?? '남';
    _grade = p?.grade ?? 'C조';
    _selectedClubId = p?.clubId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요.')),
      );
      return;
    }
    if (_selectedClubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('소속 클럽을 선택해주세요.')),
      );
      return;
    }

    // 나이 계산
    int age = widget.initial?.age ?? 0;
    final bd = _birthCtrl.text.trim();
    if (bd.length >= 2) {
      final yy = int.tryParse(bd.substring(0, 2)) ?? 0;
      final fullYear = yy <= 25 ? 2000 + yy : 1900 + yy;
      age = DateTime.now().year - fullYear;
    }

    // 클럽 정보 가져오기
    final club = SampleData.clubs.firstWhere(
      (c) => c.id == _selectedClubId,
      orElse: () => const Club(id: '', name: ''),
    );

    final updated = Player(
      id: widget.initial?.id ??
          'player_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      gender: _gender,
      birthDate: bd,
      grade: _grade,
      clubId: club.id,
      clubName: club.name,
      phone: _phoneCtrl.text.trim(),
      regNumber: widget.initial?.regNumber ??
          '2026-${(SampleData.players.length + 1).toString().padLeft(4, '0')}',
      age: age,
      awards: widget.initial?.awards ?? const [],
    );

    if (!_isEdit) {
      // 등록: 새 선수 추가
      SampleData.players.add(updated);
    }
    // 수정은 호출 측에서 SampleData 업데이트

    SampleData.savePlayers();
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final clubs = SampleData.clubs;
    if (_selectedClubId == null && clubs.isNotEmpty) {
      _selectedClubId = clubs.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        title: Text(_isEdit ? '선수 수정' : '선수 등록',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        centerTitle: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _field('이름', ctrl: _nameCtrl, hint: '홍길동')),
            const SizedBox(width: 10),
            Expanded(
                child: _drop('성별', const ['남', '여'], _gender,
                    (v) => setState(() => _gender = v!))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _field('생년월일 6자리',
                    ctrl: _birthCtrl,
                    hint: '예: 980101',
                    type: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(
                child: _drop('급수', const ['A조', 'B조', 'C조', 'D조', '초심조'],
                    _grade, (v) => setState(() => _grade = v!))),
          ]),
          const SizedBox(height: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('소속 클럽',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedClubId,
              isDense: true,
              style: const TextStyle(fontSize: 17, color: AppColors.text),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFFDDE1E7), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: clubs
                  .map((c) => DropdownMenuItem(
                      value: c.id,
                      child:
                          Text(c.name, style: const TextStyle(fontSize: 17))))
                  .toList(),
              onChanged: (v) => setState(() => _selectedClubId = v),
            ),
          ]),
          const SizedBox(height: 10),
          _field('전화번호',
              ctrl: _phoneCtrl,
              hint: '010-0000-0000',
              type: TextInputType.phone,
              formatters: [_PhoneNumberFormatter()]),
          const SizedBox(height: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('협회 등록번호',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.gray,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDE1E7))),
              child: Text(
                  widget.initial?.regNumber ??
                      '자동 부여 (2026-${(SampleData.players.length + 1).toString().padLeft(4, '0')})',
                  style: const TextStyle(fontSize: 17, color: AppColors.gray3)),
            ),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
      bottomNavigationBar: FormActionBar(
        onSubmit: _submit,
        submitLabel: _isEdit ? '저장' : '등록',
      ),
    );
  }

  Widget _field(String label,
          {required TextEditingController ctrl,
          String? hint,
          TextInputType? type,
          List<TextInputFormatter>? formatters}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: type,
            inputFormatters: formatters,
            style: const TextStyle(fontSize: 17),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 16, color: Color(0xFFAAAAAA)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFDDE1E7), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      );

  Widget _drop(String label, List<String> items, String value,
          ValueChanged<String?> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: value,
            isDense: true,
            style: const TextStyle(fontSize: 17, color: AppColors.text),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFDDE1E7), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: items
                .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(v, style: const TextStyle(fontSize: 17))))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/club.dart';
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

class ClubFormScreen extends StatefulWidget {
  final Club? initial; // null이면 등록, 값이 있으면 수정
  const ClubFormScreen({super.key, this.initial});

  @override
  State<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends State<ClubFormScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _presidentNameCtrl;
  late final TextEditingController _presidentPhoneCtrl;
  late final TextEditingController _secretaryNameCtrl;
  late final TextEditingController _secretaryPhoneCtrl;
  late final TextEditingController _venueCtrl;
  late final TextEditingController _dayCtrl;
  late final TextEditingController _timeCtrl;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _presidentNameCtrl = TextEditingController(text: c?.presidentName ?? '');
    _presidentPhoneCtrl = TextEditingController(text: c?.presidentPhone ?? '');
    _secretaryNameCtrl = TextEditingController(text: c?.secretaryName ?? '');
    _secretaryPhoneCtrl = TextEditingController(text: c?.secretaryPhone ?? '');
    _venueCtrl = TextEditingController(text: c?.venue ?? '');
    _dayCtrl = TextEditingController(text: c?.practiceDay ?? '');
    _timeCtrl = TextEditingController(text: c?.practiceTime ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _presidentNameCtrl.dispose();
    _presidentPhoneCtrl.dispose();
    _secretaryNameCtrl.dispose();
    _secretaryPhoneCtrl.dispose();
    _venueCtrl.dispose();
    _dayCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클럽명을 입력해주세요.')),
      );
      return;
    }

    // 수정된 Club 객체 반환
    final updated = Club(
      id: widget.initial?.id ?? 'club_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      presidentName: _presidentNameCtrl.text.trim(),
      presidentPhone: _presidentPhoneCtrl.text.trim(),
      secretaryName: _secretaryNameCtrl.text.trim(),
      secretaryPhone: _secretaryPhoneCtrl.text.trim(),
      venue: _venueCtrl.text.trim(),
      practiceDay: _dayCtrl.text.trim(),
      practiceTime: _timeCtrl.text.trim(),
      memberType: widget.initial?.memberType ?? '정회원',
      memberCount: widget.initial?.memberCount ?? 0,
      payStatus: widget.initial?.payStatus ?? ClubPayStatus.unpaid,
      status: widget.initial?.status ?? '활성',
      countA: widget.initial?.countA ?? 0,
      countB: widget.initial?.countB ?? 0,
      countC: widget.initial?.countC ?? 0,
      countD: widget.initial?.countD ?? 0,
      countBeginner: widget.initial?.countBeginner ?? 0,
      assocFeePaid: widget.initial?.assocFeePaid ?? false,
      sharePaid: widget.initial?.sharePaid ?? false,
      boardFeePaid: widget.initial?.boardFeePaid ?? false,
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        title: Text(
          _isEdit ? '클럽 수정' : '클럽 등록',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('클럽명', ctrl: _nameCtrl, hint: '예: 서울시배드민턴협회'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  flex: 115,
                  child:
                      _field('회장 이름', ctrl: _presidentNameCtrl, hint: '이름 입력')),
              const SizedBox(width: 10),
              Expanded(
                  flex: 185,
                  child: _field('연락처',
                      ctrl: _presidentPhoneCtrl,
                      hint: '010-0000-0000',
                      type: TextInputType.phone,
                      formatters: [_PhoneNumberFormatter()],
                      fontSize: 18,
                      hintFontSize: 17)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  flex: 115,
                  child:
                      _field('총무 이름', ctrl: _secretaryNameCtrl, hint: '이름 입력')),
              const SizedBox(width: 10),
              Expanded(
                  flex: 185,
                  child: _field('연락처',
                      ctrl: _secretaryPhoneCtrl,
                      hint: '010-0000-0000',
                      type: TextInputType.phone,
                      formatters: [_PhoneNumberFormatter()],
                      fontSize: 18,
                      hintFontSize: 17)),
            ]),
            const SizedBox(height: 12),
            _field('운동 장소', ctrl: _venueCtrl, hint: '체육관명 또는 주소'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field('요일', ctrl: _dayCtrl, hint: '예: 월·수·금')),
              const SizedBox(width: 10),
              Expanded(
                  child: _field('시간', ctrl: _timeCtrl, hint: '예: 19:00~22:00')),
            ]),
            const SizedBox(height: 20),
          ],
        ),
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
          List<TextInputFormatter>? formatters,
          double fontSize = 17,
          double hintFontSize = 16}) =>
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
            style: TextStyle(fontSize: fontSize),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  fontSize: hintFontSize, color: const Color(0xFFAAAAAA)),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
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
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

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

class PlayerFormScreen extends StatelessWidget {
  const PlayerFormScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.gray,
        appBar:
            AppBar(title: const Text('선수 등록', style: TextStyle(fontSize: 21))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _field('이름', hint: '홍길동')),
              const SizedBox(width: 10),
              Expanded(child: _drop('성별', const ['남', '여'])),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _field('생년월일 6자리',
                      hint: '예: 980101', type: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(
                  child: _drop('급수', const ['A조', 'B조', 'C조', 'D조', '초심조'])),
            ]),
            const SizedBox(height: 10),
            _drop('소속 클럽', const [
              '중앙 배드민턴 클럽',
              '동작 스매시 클럽',
              '서초 셔틀콕',
              '분당 에이스',
              '일산 스피드'
            ]),
            const SizedBox(height: 10),
            _field('전화번호',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.gray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDDE1E7))),
                child: const Text('자동 부여 (2026-016)',
                    style: TextStyle(fontSize: 17, color: AppColors.gray3)),
              ),
            ]),
            const SizedBox(height: 10),
            const Text('수상 이력 (선택)',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
            const SizedBox(height: 4),
            TextField(
              maxLines: 3,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                hintText: '예: 2025 협회장배 혼복 A급 우승',
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
            const SizedBox(height: 24),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.gray2, width: 0.5),
              ),
            ),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('등록', style: TextStyle(fontSize: 17)),
                ),
              ),
            ]),
          ),
        ),
      );

  Widget _field(String label,
          {String? hint,
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

  Widget _drop(String label, List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: items.first,
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
            onChanged: (_) {},
          ),
        ],
      );
}

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

class ClubFormScreen extends StatefulWidget {
  const ClubFormScreen({super.key});
  @override
  State<ClubFormScreen> createState() => _ClubFormScreenState();
}

class _ClubFormScreenState extends State<ClubFormScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar:
          AppBar(title: const Text('클럽 등록', style: TextStyle(fontSize: 21))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('클럽명', hint: '예: 서울시배드민턴협회'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 115, child: _field('회장 이름', hint: '이름 입력')),
              const SizedBox(width: 10),
              Expanded(
                  flex: 185,
                  child: _field('연락처',
                      hint: '010-0000-0000',
                      type: TextInputType.phone,
                      formatters: [_PhoneNumberFormatter()],
                      fontSize: 18,
                      hintFontSize: 17)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(flex: 115, child: _field('총무 이름', hint: '이름 입력')),
              const SizedBox(width: 10),
              Expanded(
                  flex: 185,
                  child: _field('연락처',
                      hint: '010-0000-0000',
                      type: TextInputType.phone,
                      formatters: [_PhoneNumberFormatter()],
                      fontSize: 18,
                      hintFontSize: 17)),
            ]),
            const SizedBox(height: 12),
            _field('운동 장소', hint: '체육관명 또는 주소'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field('요일', hint: '예: 월·수·금')),
              const SizedBox(width: 10),
              Expanded(child: _field('시간', hint: '예: 19:00~22:00')),
            ]),
            const SizedBox(height: 20),
          ],
        ),
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
  }

  Widget _field(String label,
          {String? hint,
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

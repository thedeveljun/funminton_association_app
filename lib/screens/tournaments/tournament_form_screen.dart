import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/common/form_action_bar.dart';

class TournamentFormScreen extends StatelessWidget {
  const TournamentFormScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.gray,
        appBar: AppBar(
          title: const Text('대회 등록',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          centerTitle: false,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _f('대회명', hint: '예: 2026 협회장배 배드민턴 대회'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _f('시작일')),
              const SizedBox(width: 10),
              Expanded(child: _f('종료일')),
            ]),
            const SizedBox(height: 12),
            _f('대회 장소', hint: '체육관명 또는 주소'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dd('종별', ['혼복', '남복', '여복', '전체'])),
              const SizedBox(width: 10),
              Expanded(child: _dd('대상 급수', ['전체', 'A급', 'B급', 'C급', 'D급'])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child:
                      _f('참가비 (원)', hint: '30000', type: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _f('신청 마감일')),
            ]),
            const SizedBox(height: 12),
            const Text('안내 사항',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
            const SizedBox(height: 5),
            TextField(
                maxLines: 3,
                decoration: const InputDecoration(hintText: '대회 관련 안내 사항 입력')),
            const SizedBox(height: 20),
          ]),
        ),
        bottomNavigationBar: FormActionBar(
          onSubmit: () => Navigator.pop(context),
          submitLabel: '등록',
        ),
      );

  Widget _f(String lbl, {String? hint, TextInputType? type}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lbl,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2)),
          const SizedBox(height: 5),
          TextField(
              keyboardType: type, decoration: InputDecoration(hintText: hint)),
        ],
      );

  Widget _dd(String lbl, List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lbl,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2)),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: items.first,
            decoration: const InputDecoration(),
            items: items
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (_) {},
          ),
        ],
      );
}

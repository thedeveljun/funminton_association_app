// lib/screens/finance/finance_log_screen.dart
//
// 재정 변경 이력 화면 — 펀클럽(funminton_club_app) 이력 화면을 옮겨 왔다.
// 수입·지출·협회비·분담금을 고치거나 지운 기록. 여기서는 지울 수 없다.

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/finance_log.dart';
import 'widgets/widgets.dart';

class FinanceLogScreen extends StatefulWidget {
  const FinanceLogScreen({super.key});

  @override
  State<FinanceLogScreen> createState() => _FinanceLogScreenState();
}

class _FinanceLogScreenState extends State<FinanceLogScreen> {
  List<FinanceLogEntry>? _entries;

  @override
  void initState() {
    super.initState();
    FinanceLog.load().then((e) {
      if (mounted) setState(() => _entries = e);
    });
  }

  void _share() {
    final list = _entries ?? const [];
    if (list.isEmpty) return;
    final text = '[재정 변경 이력]\n\n${list.map((e) {
      final d = e.detail.isEmpty ? '' : '\n   ${e.detail}';
      return '${fmtStamp(e.at)}  ${e.what} · ${e.target}$d';
    }).join('\n')}';
    Share.share(text);
  }

  /// 지우거나 줄인 기록은 눈에 띄게.
  bool _warn(FinanceLogEntry e) =>
      e.what.contains('삭제') || e.what.contains('반납') || e.what.contains('취소');

  @override
  Widget build(BuildContext context) {
    final list = _entries;
    return Scaffold(
      backgroundColor: kBgPage,
      appBar: AppBar(
        backgroundColor: kBgPage,
        surfaceTintColor: kBgPage,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: -4,
        leadingWidth: 34,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: kInk),
        ),
        title: const Text('재정 변경 이력',
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: kInk)),
        actions: [
          IconButton(
            onPressed: _share,
            tooltip: '이력 공유',
            icon: const Icon(Icons.share_outlined, size: 22, color: kAccent),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: kBannerNavyAlt,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: const Text(
            '수입·지출·협회비·분담금을 고치거나 지운 기록입니다. 여기서는 지울 수 없습니다.',
            style: TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
          ),
        ),
        Expanded(
          child: list == null
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? const Center(
                      child: Text('아직 바꾼 기록이 없습니다.',
                          style: TextStyle(color: Color(0xFFAAAAAA))))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final e = list[i];
                        final warn = _warn(e);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: warn ? kExpenseCardBg : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    warn ? kExpenseBorder : kCardBorderLight,
                                width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF2F7),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(e.what,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: kInk)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(e.target,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: kInk)),
                                ),
                                Text(fmtStamp(e.at),
                                    style: const TextStyle(
                                        fontSize: 12, color: kInk)),
                              ]),
                              if (e.detail.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(e.detail,
                                    style: const TextStyle(
                                        fontSize: 13, color: kInk)),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

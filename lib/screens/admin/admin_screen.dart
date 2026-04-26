import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        title: const Text('협회 행정'),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              '작성',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tc,
          tabs: const [
            Tab(text: '공지사항'),
            Tab(text: '이사회'),
            Tab(text: '공문'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: const [
          _NoticeList(),
          _BoardList(),
          _DocumentList(),
        ],
      ),
    );
  }
}

// ── 공지사항 ──────────────────────────────────
class _NoticeList extends StatelessWidget {
  const _NoticeList();

  static const List<Map<String, String>> _notices = [
    {
      'title': '2026년도 협회비 납부 안내',
      'date': '2026-04-10',
      'type': '중요',
      'content': '각 클럽은 2026년 4월 30일까지 협회비를 납부해 주시기 바랍니다.',
    },
    {
      'title': '2026 협회장배 대회 일정 공지',
      'date': '2026-04-01',
      'type': '일반',
      'content': '2026 협회장배 대회 일정이 확정되었습니다. 참가 신청은 4월 30일까지입니다.',
    },
    {
      'title': '협회 임원 선출 안내',
      'date': '2026-03-20',
      'type': '중요',
      'content': '2026년도 협회 임원 선출이 진행됩니다.',
    },
    {
      'title': '심판 교육 실시 안내',
      'date': '2026-03-10',
      'type': '일반',
      'content': '심판 자격 향상을 위한 교육을 실시합니다.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _notices.length,
      itemBuilder: (_, i) {
        final n = _notices[i];
        final isImportant = n['type'] == '중요';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.divider),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isImportant ? AppColors.red3 : AppColors.gray2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          n['type']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isImportant
                                ? const Color(0xFF742A2A)
                                : AppColors.text2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          n['title']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      n['content']!,
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n['date']!,
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.gray3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray3, size: 18),
            ],
          ),
        );
      },
    );
  }
}

// ── 이사회 ────────────────────────────────────
class _BoardList extends StatelessWidget {
  const _BoardList();

  static const List<Map<String, String>> _items = [
    {
      'title': '2026년 1분기 이사회',
      'date': '2026-04-15',
      'place': '협회 회의실',
      'status': '완료',
    },
    {
      'title': '2026년 2분기 이사회',
      'date': '2026-07-20',
      'place': '협회 회의실',
      'status': '예정',
    },
    {
      'title': '2026년 3분기 이사회',
      'date': '2026-10-12',
      'place': '협회 회의실',
      'status': '예정',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final it = _items[i];
        final isDone = it['status'] == '완료';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.divider),
            ),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.blue3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('📋', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it['title']!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${it['date']} · ${it['place']}',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDone ? AppColors.green3 : AppColors.blue3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                it['status']!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDone
                      ? const Color(0xFF1C4532)
                      : const Color(0xFF1A365D),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── 공문 ──────────────────────────────────────
class _DocumentList extends StatelessWidget {
  const _DocumentList();

  static const List<Map<String, String>> _docs = [
    {
      'title': '협회장배 개최 협조 요청',
      'date': '2026-03-25',
      'to': '강남구청',
    },
    {
      'title': '선수 등록 현황 보고',
      'date': '2026-03-01',
      'to': '대한배드민턴협회',
    },
    {
      'title': '대회 심판 파견 요청',
      'date': '2026-02-14',
      'to': '서울시체육회',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _docs.length,
      itemBuilder: (_, i) {
        final d = _docs[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.divider),
            ),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.amber2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('📄', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d['title']!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${d['date']} → ${d['to']}',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.download, color: AppColors.blue2, size: 20),
          ]),
        );
      },
    );
  }
}

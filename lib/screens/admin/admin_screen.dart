import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/admin_records.dart';
import '../../services/sample_data.dart';
import 'notice_sms_sheet.dart';

const _adminInk = Color(0xFF0D1B3E);

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
    _tc.addListener(() {
      if (mounted) setState(() {}); // '+' 라벨이 탭에 따라 바뀌도록
    });
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  String get _addLabel {
    switch (_tc.index) {
      case 1:
        return '이사회';
      case 2:
        return '공문';
      default:
        return '공지';
    }
  }

  Future<void> _onAdd() async {
    switch (_tc.index) {
      case 0:
        await _addNotice();
        break;
      case 1:
        await _addBoard();
        break;
      case 2:
        await _addDoc();
        break;
    }
  }

  // ─── 공지사항 CRUD ─────────────────────────
  Future<void> _addNotice() async {
    final created = await _showNoticeForm();
    if (created == null) return;
    setState(() => SampleData.notices.add(created));
    await SampleData.saveNotices();
  }

  Future<void> _editNotice(Notice n) async {
    final updated = await _showNoticeForm(initial: n);
    if (updated == null) return;
    final i = SampleData.notices.indexWhere((x) => x.id == n.id);
    if (i < 0) return;
    setState(() => SampleData.notices[i] = updated);
    await SampleData.saveNotices();
  }

  Future<void> _deleteNotice(Notice n) async {
    if (!await _confirmDelete(n.title)) return;
    setState(() => SampleData.notices.removeWhere((x) => x.id == n.id));
    await SampleData.saveNotices();
  }

  Future<void> _smsNotice(Notice n) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => NoticeSmsSheet(notice: n),
    );
  }

  // ─── 이사회 CRUD ──────────────────────────
  Future<void> _addBoard() async {
    final created = await _showBoardForm();
    if (created == null) return;
    setState(() => SampleData.boards.add(created));
    await SampleData.saveBoards();
  }

  Future<void> _editBoard(BoardMeeting b) async {
    final updated = await _showBoardForm(initial: b);
    if (updated == null) return;
    final i = SampleData.boards.indexWhere((x) => x.id == b.id);
    if (i < 0) return;
    setState(() => SampleData.boards[i] = updated);
    await SampleData.saveBoards();
  }

  Future<void> _deleteBoard(BoardMeeting b) async {
    if (!await _confirmDelete(b.title)) return;
    setState(() => SampleData.boards.removeWhere((x) => x.id == b.id));
    await SampleData.saveBoards();
  }

  // ─── 공문 CRUD ────────────────────────────
  Future<void> _addDoc() async {
    final created = await _showDocForm();
    if (created == null) return;
    setState(() => SampleData.docs.add(created));
    await SampleData.saveDocs();
  }

  Future<void> _editDoc(OfficialDoc d) async {
    final updated = await _showDocForm(initial: d);
    if (updated == null) return;
    final i = SampleData.docs.indexWhere((x) => x.id == d.id);
    if (i < 0) return;
    setState(() => SampleData.docs[i] = updated);
    await SampleData.saveDocs();
  }

  Future<void> _deleteDoc(OfficialDoc d) async {
    if (!await _confirmDelete(d.title)) return;
    setState(() => SampleData.docs.removeWhere((x) => x.id == d.id));
    await SampleData.saveDocs();
  }

  Future<bool> _confirmDelete(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$title 삭제'),
        content: const Text('삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    return ok == true;
  }

  // ─── 폼 시트들 ────────────────────────────
  Future<Notice?> _showNoticeForm({Notice? initial}) =>
      showModalBottomSheet<Notice>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _NoticeForm(initial: initial),
      );

  Future<BoardMeeting?> _showBoardForm({BoardMeeting? initial}) =>
      showModalBottomSheet<BoardMeeting>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _BoardForm(initial: initial),
      );

  Future<OfficialDoc?> _showDocForm({OfficialDoc? initial}) =>
      showModalBottomSheet<OfficialDoc>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _DocForm(initial: initial),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: -4,
        leadingWidth: 34,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.maybePop(context),
          icon:
              const Icon(Icons.arrow_back_ios_new, size: 20, color: _adminInk),
        ),
        title: const Text(
          '협회 행정',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: _adminInk,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              _addLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tc,
          labelStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: '공지사항'),
            Tab(text: '이사회'),
            Tab(text: '공문'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: [
          _NoticeList(
            onTap: _editNotice,
            onDelete: _deleteNotice,
            onSms: _smsNotice,
          ),
          _BoardList(onTap: _editBoard, onDelete: _deleteBoard),
          _DocumentList(onTap: _editDoc, onDelete: _deleteDoc),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  공지사항 리스트
// ═══════════════════════════════════════════════════════
class _NoticeList extends StatelessWidget {
  final ValueChanged<Notice> onTap;
  final ValueChanged<Notice> onDelete;
  final ValueChanged<Notice> onSms;
  const _NoticeList({
    required this.onTap,
    required this.onDelete,
    required this.onSms,
  });

  @override
  Widget build(BuildContext context) {
    final items = [...SampleData.notices]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (items.isEmpty) return const _EmptyHint(text: '공지사항이 없습니다.');
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final n = items[i];
        final isImportant = n.type == '중요';
        final alt = i.isOdd;
        return InkWell(
          onTap: () => onTap(n),
          onLongPress: () => onDelete(n),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: alt ? const Color(0xFFEEF1F7) : AppColors.white,
              border:
                  const Border(bottom: BorderSide(color: AppColors.divider)),
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
                            color:
                                isImportant ? AppColors.red3 : AppColors.gray2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(n.type,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isImportant
                                    ? const Color(0xFF742A2A)
                                    : AppColors.text2,
                              )),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(n.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              )),
                        ),
                      ]),
                      if (n.content.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(n.content,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF4B5563)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 2),
                      Text(n.date,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.gray3)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '클럽 회장·총무에게 SMS 발송',
                  icon: const Icon(Icons.sms_rounded,
                      color: AppColors.primaryMid, size: 20),
                  onPressed: () => onSms(n),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.gray3, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
//  이사회 리스트
// ═══════════════════════════════════════════════════════
class _BoardList extends StatelessWidget {
  final ValueChanged<BoardMeeting> onTap;
  final ValueChanged<BoardMeeting> onDelete;
  const _BoardList({required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final items = [...SampleData.boards]
      ..sort((a, b) => a.date.compareTo(b.date));
    if (items.isEmpty) return const _EmptyHint(text: '등록된 이사회가 없습니다.');
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final isDone = it.status == '완료';
        final alt = i.isOdd;
        return InkWell(
          onTap: () => onTap(it),
          onLongPress: () => onDelete(it),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: alt ? const Color(0xFFEEF1F7) : AppColors.white,
              border:
                  const Border(bottom: BorderSide(color: AppColors.divider)),
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
                  child: Icon(
                    Icons.groups_rounded,
                    size: 22,
                    color: AppColors.primaryMid,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        )),
                    const SizedBox(height: 2),
                    Text(
                        '${it.date}${it.place.isEmpty ? '' : ' · ${it.place}'}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF4B5563))),
                    if (it.agenda.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(it.agenda,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF4B5563)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone ? AppColors.green3 : AppColors.blue3,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(it.status,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDone
                          ? const Color(0xFF1C4532)
                          : const Color(0xFF1A365D),
                    )),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
//  공문 리스트
// ═══════════════════════════════════════════════════════
class _DocumentList extends StatelessWidget {
  final ValueChanged<OfficialDoc> onTap;
  final ValueChanged<OfficialDoc> onDelete;
  const _DocumentList({required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final items = [...SampleData.docs]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (items.isEmpty) return const _EmptyHint(text: '등록된 공문이 없습니다.');
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final d = items[i];
        final alt = i.isOdd;
        return InkWell(
          onTap: () => onTap(d),
          onLongPress: () => onDelete(d),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: alt ? const Color(0xFFEEF1F7) : AppColors.white,
              border:
                  const Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.mail_outline_rounded,
                    size: 22,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        )),
                    const SizedBox(height: 2),
                    Text('${d.date}${d.to.isEmpty ? '' : ' → ${d.to}'}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF4B5563))),
                    if (d.content.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(d.content,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF4B5563)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.gray3, size: 18),
            ]),
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '$text\n우측 상단 [+] 버튼으로 추가하세요.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════
//  공통 폼 헬퍼
// ═══════════════════════════════════════════════════════
class _FormShell extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback onSubmit;
  final String submitLabel;

  const _FormShell({
    required this.title,
    required this.children,
    required this.onSubmit,
    required this.submitLabel,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset =
        mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.padding.bottom;
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
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 12),
            ...children,
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
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMid,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(submitLabel),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text2)),
    );

// 입력 박스 폰트 스타일 (기존보다 1pt 크고 약간 진하게)
const _fieldTextStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
const _titleFieldStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

Widget _field(TextEditingController c,
        {String? hint, int maxLines = 1, TextStyle? style}) =>
    TextField(
      controller: c,
      maxLines: maxLines,
      style: style ?? _fieldTextStyle,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        // 박스 높이 약 20% 축소: vertical 8 → 5
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
    );

Future<String?> _pickDate(BuildContext context, String current) async {
  final initial = DateTime.tryParse(current) ?? DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (picked == null) return null;
  return '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
}

Widget _dateBtn(String value, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32, // 40 → 32 (20% 축소)
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD8DEE8)),
        ),
        child: Row(children: [
          Text(value.isEmpty ? 'YYYY-MM-DD' : value,
              style: TextStyle(
                fontSize: 15, // 14 → 15
                fontWeight: FontWeight.w500, // 약간 진하게
                color: value.isEmpty ? const Color(0xFFAAAAAA) : AppColors.text,
              )),
          const Spacer(),
          const Icon(Icons.calendar_today_outlined,
              size: 16, color: AppColors.muted),
        ]),
      ),
    );

// ═══════════════════════════════════════════════════════
//  공지사항 폼
// ═══════════════════════════════════════════════════════
class _NoticeForm extends StatefulWidget {
  final Notice? initial;
  const _NoticeForm({this.initial});

  @override
  State<_NoticeForm> createState() => _NoticeFormState();
}

class _NoticeFormState extends State<_NoticeForm> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  String _date = '';
  String _type = '일반';

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final n = widget.initial;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _contentCtrl = TextEditingController(text: n?.content ?? '');
    _date = n?.date ?? DateTime.now().toIso8601String().substring(0, 10);
    _type = n?.type ?? '일반';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목을 입력하세요.')));
      return;
    }
    final id =
        widget.initial?.id ?? 'n_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
        context,
        Notice(
          id: id,
          title: _titleCtrl.text.trim(),
          type: _type,
          date: _date,
          content: _contentCtrl.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _FormShell(
      title: _isEdit ? '공지사항 수정' : '공지사항 추가',
      submitLabel: _isEdit ? '저장' : '추가',
      onSubmit: _submit,
      children: [
        _label('제목'),
        _field(_titleCtrl,
            hint: '예: 2026년도 협회비 납부 안내', style: _titleFieldStyle),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('날짜'),
              _dateBtn(_date, () async {
                final picked = await _pickDate(context, _date);
                if (picked != null) setState(() => _date = picked);
              }),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('분류'),
              _TypeSelector(
                options: const ['일반', '중요'],
                value: _type,
                onChanged: (v) => setState(() => _type = v),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        _label('내용'),
        _field(_contentCtrl, hint: '내용 입력', maxLines: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  이사회 폼
// ═══════════════════════════════════════════════════════
class _BoardForm extends StatefulWidget {
  final BoardMeeting? initial;
  const _BoardForm({this.initial});

  @override
  State<_BoardForm> createState() => _BoardFormState();
}

class _BoardFormState extends State<_BoardForm> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _placeCtrl;
  late final TextEditingController _agendaCtrl;
  String _date = '';
  String _status = '예정';

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    _titleCtrl = TextEditingController(text: b?.title ?? '');
    _placeCtrl = TextEditingController(text: b?.place ?? '');
    _agendaCtrl = TextEditingController(text: b?.agenda ?? '');
    _date = b?.date ?? DateTime.now().toIso8601String().substring(0, 10);
    _status = b?.status ?? '예정';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _placeCtrl.dispose();
    _agendaCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목을 입력하세요.')));
      return;
    }
    final id =
        widget.initial?.id ?? 'b_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
        context,
        BoardMeeting(
          id: id,
          title: _titleCtrl.text.trim(),
          date: _date,
          place: _placeCtrl.text.trim(),
          status: _status,
          agenda: _agendaCtrl.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _FormShell(
      title: _isEdit ? '이사회 수정' : '이사회 추가',
      submitLabel: _isEdit ? '저장' : '추가',
      onSubmit: _submit,
      children: [
        _label('제목'),
        _field(_titleCtrl, hint: '예: 2026년 2분기 이사회', style: _titleFieldStyle),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('일자'),
              _dateBtn(_date, () async {
                final picked = await _pickDate(context, _date);
                if (picked != null) setState(() => _date = picked);
              }),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('상태'),
              _TypeSelector(
                options: const ['예정', '완료'],
                value: _status,
                onChanged: (v) => setState(() => _status = v),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        _label('장소'),
        _field(_placeCtrl, hint: '예: 협회 회의실'),
        const SizedBox(height: 8),
        _label('안건/메모'),
        _field(_agendaCtrl, hint: '안건 또는 메모 입력', maxLines: 3),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  공문 폼
// ═══════════════════════════════════════════════════════
class _DocForm extends StatefulWidget {
  final OfficialDoc? initial;
  const _DocForm({this.initial});

  @override
  State<_DocForm> createState() => _DocFormState();
}

class _DocFormState extends State<_DocForm> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _toCtrl;
  late final TextEditingController _contentCtrl;
  String _date = '';

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _titleCtrl = TextEditingController(text: d?.title ?? '');
    _toCtrl = TextEditingController(text: d?.to ?? '');
    _contentCtrl = TextEditingController(text: d?.content ?? '');
    _date = d?.date ?? DateTime.now().toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _toCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목을 입력하세요.')));
      return;
    }
    final id =
        widget.initial?.id ?? 'd_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
        context,
        OfficialDoc(
          id: id,
          title: _titleCtrl.text.trim(),
          date: _date,
          to: _toCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return _FormShell(
      title: _isEdit ? '공문 수정' : '공문 추가',
      submitLabel: _isEdit ? '저장' : '추가',
      onSubmit: _submit,
      children: [
        _label('제목'),
        _field(_titleCtrl, hint: '예: 협회장배 개최 협조 요청', style: _titleFieldStyle),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('발송일'),
              _dateBtn(_date, () async {
                final picked = await _pickDate(context, _date);
                if (picked != null) setState(() => _date = picked);
              }),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('수신처'),
              _field(_toCtrl, hint: '예: 강남구청'),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        _label('내용'),
        _field(_contentCtrl, hint: '내용 입력', maxLines: 4),
      ],
    );
  }
}

// 공통 분류/상태 선택기 (작은 칩 그룹)
class _TypeSelector extends StatelessWidget {
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  const _TypeSelector({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32, // 40 → 32 (20% 축소)
      child: Row(
        children: options.map((o) {
          final on = o == value;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5), // 9 → 5
                decoration: BoxDecoration(
                  color: on ? AppColors.primaryMid : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: on ? AppColors.primaryMid : const Color(0xFFD8DEE8),
                    width: on ? 1.5 : 1,
                  ),
                ),
                child: Text(o,
                    style: TextStyle(
                      fontSize: 14, // 13 → 14
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppColors.text2,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

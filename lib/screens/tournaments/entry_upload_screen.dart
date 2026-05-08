import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/player.dart';
import '../../services/sample_data.dart';

const _blue = Color(0xFF2563EB);
const _ink = Color(0xFF0D1B3E);
const _muted = Color(0xFF9BA8BB);
const _subtitle = Color(0xFF4B5563);
const _green = Color(0xFF22A06B);
const _red = Color(0xFFB91C1C);
const _soft = Color(0xFFF4F6FA);
const _warnBg = Color(0xFFFEF3C7);
const _warnBorder = Color(0xFFFCD34D);
const _warnIcon = Color(0xFFB45309);
const _warnText = Color(0xFF92400E);

const _assetPath = 'assets/excel/대회_참가신청_샘플.xlsx';
const _sampleName = '대회_참가신청_샘플.xlsx';
const _validEvents = ['혼복', '남복', '여복', '단식'];

/// 한 행의 신청 데이터 (in-session, 영속화 X).
class EntryRow {
  final String name;
  final String clubName;
  final String event; // 혼복 / 남복 / 여복 / 단식
  final String grade; // 정규화 후
  final String partnerName;
  final String partnerClubName; // 파트너가 타클럽일 수 있음. 같은 클럽이면 clubName 과 동일.
  final String phone;
  EntryRow({
    required this.name,
    required this.clubName,
    required this.event,
    required this.grade,
    required this.partnerName,
    required this.partnerClubName,
    required this.phone,
  });
}

/// 업로드 결과: 호출자가 _selected 갱신 + 종목별 카운트 표시에 사용.
class EntryUploadResult {
  final List<String> selectedPlayerIds;
  final Map<String, int> eventCounts; // 혼복/남복/여복/단식
  final int newPlayerCount;
  final int unmatchedPartnerCount;
  EntryUploadResult({
    required this.selectedPlayerIds,
    required this.eventCounts,
    required this.newPlayerCount,
    required this.unmatchedPartnerCount,
  });
}

String _normalizeGrade(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  final upper = s.toUpperCase().replaceAll(' ', '');
  final m = RegExp(r'^([A-Z])(조|급)?$').firstMatch(upper);
  if (m != null) return '${m.group(1)}조';
  if (s == '초심' || s == '초심조' || s == '초심자' || s == '입문' || s == '입문조') {
    return '초심조';
  }
  if (s == '자강' || s == '자강조') return '자강조';
  return s;
}

String _normalizeEvent(String raw) {
  final s = raw.trim().replaceAll(' ', '');
  if (s.isEmpty) return '';
  if (s == '혼복' || s == '혼합복식' || s == 'XD') return '혼복';
  if (s == '남복' || s == '남자복식' || s == 'MD') return '남복';
  if (s == '여복' || s == '여자복식' || s == 'WD') return '여복';
  if (s == '단식' || s == 'MS' || s == 'WS' || s == '싱글') return '단식';
  return s;
}

class EntryUploadScreen extends StatefulWidget {
  /// 누적 모드: 이 화면 호출자가 기존 _selected 를 그대로 들고 있고, 업로드 완료 시
  /// 매칭/신규 추가된 player id 들을 합쳐서 사용.
  final Set<String> existingSelected;
  const EntryUploadScreen({super.key, required this.existingSelected});

  @override
  State<EntryUploadScreen> createState() => _EntryUploadScreenState();
}

class _EntryUploadScreenState extends State<EntryUploadScreen> {
  bool _isLoading = false;
  String? _errorMsg;
  String? _warningMsg;
  List<EntryRow> _preview = [];
  String? _fileName;
  String? _savedPath;
  bool _uploaded = false;

  String _normalizeKey(String s) =>
      s.replaceAll(' ', '').replaceAll('*', '').trim();

  String _getValue(Map<String, String> row, List<String> candidates) {
    for (final key in row.keys) {
      final nk = _normalizeKey(key);
      for (final c in candidates) {
        if (nk == _normalizeKey(c)) return row[key] ?? '';
      }
    }
    return '';
  }

  Future<void> _downloadSample() async {
    setState(() => _isLoading = true);
    try {
      final data = await rootBundle.load(_assetPath);
      Directory? dir;
      if (Platform.isAndroid) {
        try {
          dir = Directory('/storage/emulated/0/Download');
          if (!await dir.exists()) {
            dir = await getApplicationDocumentsDirectory();
          }
        } catch (_) {
          dir = await getApplicationDocumentsDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final file = File('${dir.path}/$_sampleName');
      await file.writeAsBytes(data.buffer.asUint8List());
      setState(() => _savedPath = file.path);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: const [
              Icon(Icons.check_circle_rounded, color: _green),
              SizedBox(width: 8),
              Text('다운로드 완료',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('파일이 저장되었습니다.', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('저장 위치',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _muted)),
                      const SizedBox(height: 4),
                      Text(file.path,
                          style: const TextStyle(
                              fontSize: 12,
                              color: _ink,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('샘플 파일 저장 실패: $e'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _errorMsg = null;
      _warningMsg = null;
      _preview = [];
      _fileName = null;
      _uploaded = false;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _isLoading = true;
      _fileName = file.name;
    });

    try {
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final excel = xl.Excel.decodeBytes(bytes);

      // '대회 참가신청' 시트 우선
      xl.Sheet? sheet;
      for (final entry in excel.tables.entries) {
        if (entry.key.contains('참가신청') || entry.key.contains('참가')) {
          sheet = entry.value;
          break;
        }
      }
      if (sheet == null) {
        for (final s in excel.tables.values) {
          if (s.rows.length > 2) {
            sheet = s;
            break;
          }
        }
        sheet ??= excel.tables.values.first;
      }

      // 헤더 행 자동 탐지
      int headerRowIdx = 1;
      int maxKeyword = 0;
      const keywords = ['이름', '클럽', '종목', '급수'];
      for (var i = 0; i < sheet.rows.length && i < 5; i++) {
        int matched = 0;
        for (final cell in sheet.rows[i]) {
          final v = cell?.value?.toString() ?? '';
          for (final kw in keywords) {
            if (v.contains(kw)) {
              matched++;
              break;
            }
          }
        }
        if (matched > maxKeyword) {
          maxKeyword = matched;
          headerRowIdx = i;
        }
      }
      final headerRow = sheet.rows[headerRowIdx];
      final headers =
          headerRow.map((c) => c?.value?.toString().trim() ?? '').toList();
      int coreIdx = -1;
      for (var j = 0; j < headers.length; j++) {
        if (_normalizeKey(headers[j]).contains('이름')) {
          coreIdx = j;
          break;
        }
      }

      final rawRows = <Map<String, String>>[];
      for (var i = headerRowIdx + 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final map = <String, String>{};
        bool isExample = false;
        for (var j = 0; j < row.length && j < headers.length; j++) {
          final val = row[j]?.value?.toString().trim() ?? '';
          if (headers[j].isNotEmpty) {
            map[headers[j]] = val;
            if (j == 0 && val == '예시') isExample = true;
          }
        }
        if (isExample) continue;
        if (coreIdx >= 0) {
          final coreVal = row.length > coreIdx
              ? row[coreIdx]?.value?.toString().trim() ?? ''
              : '';
          if (coreVal.isEmpty) continue;
        }
        rawRows.add(map);
      }

      if (rawRows.isEmpty) {
        setState(() {
          _errorMsg = '데이터가 없습니다. 샘플 양식에 맞게 입력했는지 확인해주세요.';
          _isLoading = false;
        });
        return;
      }

      // 같은 사람·종목 중복 → 마지막 값으로 덮어씀
      final dedup = <String, EntryRow>{};
      final errors = <String>[];
      int normalizedGradeCount = 0;
      int normalizedEventCount = 0;
      for (var i = 0; i < rawRows.length; i++) {
        final row = rawRows[i];
        final name = _getValue(row, ['이름']);
        final clubName = _getValue(row, ['소속클럽', '소속 클럽', '클럽명', '클럽']);
        final eventRaw = _getValue(row, ['종목']);
        final event = _normalizeEvent(eventRaw);
        final gradeRaw = _getValue(row, ['급수']);
        final grade = _normalizeGrade(gradeRaw);
        final partner = _getValue(row, ['파트너이름', '파트너 이름', '파트너']);
        final partnerClubRaw = _getValue(
            row, ['파트너소속클럽', '파트너 소속클럽', '파트너 소속 클럽', '파트너클럽']);
        // 파트너 클럽이 비어있으면 본인과 같은 클럽으로 가정
        final partnerClub = partnerClubRaw.isEmpty ? clubName : partnerClubRaw;
        final phone = _getValue(row, ['연락처', '전화번호']);

        if (name.isEmpty) {
          errors.add('${i + 1}번째 데이터: 이름 필수');
          continue;
        }
        if (clubName.isEmpty) {
          errors.add('${i + 1}번째 데이터: 소속클럽 필수');
          continue;
        }
        if (event.isEmpty) {
          errors.add('${i + 1}번째 데이터: 종목 필수');
          continue;
        }
        if (!_validEvents.contains(event)) {
          errors.add('${i + 1}번째: 종목은 혼복/남복/여복/단식 중 하나');
          continue;
        }
        if (eventRaw != event) normalizedEventCount++;
        if (gradeRaw.isNotEmpty && grade != gradeRaw) normalizedGradeCount++;

        final key = '$name|$clubName|$event';
        dedup[key] = EntryRow(
          name: name,
          clubName: clubName,
          event: event,
          grade: grade,
          partnerName: partner,
          partnerClubName: partnerClub,
          phone: phone,
        );
      }

      if (errors.isNotEmpty) {
        setState(() {
          _errorMsg = errors.take(5).join('\n') +
              (errors.length > 5 ? '\n외 ${errors.length - 5}건' : '');
          _isLoading = false;
        });
        return;
      }

      final entries = dedup.values.toList();

      // 파트너 페어 검증: 같은 엑셀에 양쪽이 있어야 하고, 각자 상대를 (이름+클럽)으로
      // 정확히 가리키고 있어야 한다. 타클럽 파트너의 경우 그 클럽 엑셀이 아직 안 올라왔을
      // 수 있으므로 경고일 뿐 차단은 아님.
      int unmatchedPartner = 0;
      for (final e in entries) {
        if (e.event == '단식') continue;
        if (e.partnerName.isEmpty) {
          unmatchedPartner++;
          continue;
        }
        final found = entries.any((o) =>
            o.event == e.event &&
            o.name == e.partnerName &&
            o.clubName == e.partnerClubName &&
            o.partnerName == e.name &&
            o.partnerClubName == e.clubName);
        if (!found) unmatchedPartner++;
      }

      final warnings = <String>[];
      if (normalizedGradeCount > 0) {
        warnings.add('급수 자동 정규화 $normalizedGradeCount건 (예: A → A조)');
      }
      if (normalizedEventCount > 0) {
        warnings.add('종목 자동 정규화 $normalizedEventCount건 (예: 혼합복식 → 혼복)');
      }
      if (unmatchedPartner > 0) {
        warnings
            .add('파트너 페어 미매칭 $unmatchedPartner건 — 같은 엑셀에 두 사람이 같이 있어야 함');
      }
      if (rawRows.length != entries.length) {
        warnings.add('중복 ${rawRows.length - entries.length}건 마지막 값으로 덮어씀');
      }

      setState(() {
        _preview = entries;
        _warningMsg = warnings.isEmpty ? null : warnings.join('\n');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = '파일을 읽을 수 없습니다: $e';
        _isLoading = false;
      });
    }
  }

  void _register() {
    if (_preview.isEmpty) return;

    final selected = {...widget.existingSelected};
    final eventCounts = {'혼복': 0, '남복': 0, '여복': 0, '단식': 0};
    int newPlayerCount = 0;
    int unmatchedPartner = 0;

    int seq = SampleData.players.length;
    for (final e in _preview) {
      // 이름+클럽으로 매칭. 없으면 자동 신규 등록.
      Player? p;
      for (final pl in SampleData.players) {
        if (pl.name == e.name && pl.clubName == e.clubName) {
          p = pl;
          break;
        }
      }
      if (p == null) {
        seq++;
        final club =
            SampleData.clubs.where((c) => c.name == e.clubName).firstOrNull;
        p = Player(
          id: 'player_${DateTime.now().millisecondsSinceEpoch}_$seq',
          name: e.name,
          gender: e.event == '여복' ? '여' : '남',
          grade: e.grade.isEmpty ? 'C조' : e.grade,
          clubId: club?.id ?? '',
          clubName: e.clubName,
          phone: e.phone,
          birthDate: '',
          age: 0,
          regNumber: '2026-${seq.toString().padLeft(4, '0')}',
        );
        SampleData.players.add(p);
        newPlayerCount++;
      }
      selected.add(p.id);
      if (eventCounts.containsKey(e.event)) {
        eventCounts[e.event] = eventCounts[e.event]! + 1;
      }

      if (e.event != '단식') {
        if (e.partnerName.isEmpty) {
          unmatchedPartner++;
        } else {
          final ok = _preview.any((o) =>
              o.event == e.event &&
              o.name == e.partnerName &&
              o.clubName == e.partnerClubName &&
              o.partnerName == e.name &&
              o.partnerClubName == e.clubName);
          if (!ok) unmatchedPartner++;
        }
      }
    }

    setState(() => _uploaded = true);

    // 신규 등록된 선수가 있으면 즉시 영구 저장 (앱 재실행 후에도 유지)
    if (newPlayerCount > 0) {
      SampleData.savePlayers();
    }

    final result = EntryUploadResult(
      selectedPlayerIds: selected.toList(),
      eventCounts: eventCounts,
      newPlayerCount: newPlayerCount,
      unmatchedPartnerCount: unmatchedPartner,
    );

    final lines = <String>['${_preview.length}건 등록되었습니다.'];
    if (newPlayerCount > 0) {
      lines.add('신규 선수 $newPlayerCount명 자동 등록');
    }
    if (unmatchedPartner > 0) {
      lines.add('파트너 페어 미매칭 $unmatchedPartner건 — 추후 보정 필요');
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: const [
          Icon(Icons.check_circle_rounded, color: Color(0xFF22A06B)),
          SizedBox(width: 8),
          Text('등록 완료',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: Text(lines.join('\n'),
            style: const TextStyle(fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, result);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _soft,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: -4,
        leadingWidth: 34,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: _ink),
        ),
        title: const Text('대회 참가신청 업로드',
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, color: _ink)),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('처리 중...', style: TextStyle(color: _muted)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepCard(
                    step: '1',
                    title: '샘플 파일 다운로드',
                    subtitle: '클럽 총무용 양식 — 회원에게 받아 작성 후 업로드',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _downloadSample,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('$_sampleName 다운로드'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _blue,
                            side: const BorderSide(color: _blue, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (_savedPath != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.check_circle_rounded,
                                      size: 16, color: _green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_savedPath!,
                                        style: const TextStyle(
                                            fontSize: 11, color: _subtitle)),
                                  ),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          OpenFilex.open(_savedPath!),
                                      icon: const Icon(Icons.open_in_new,
                                          size: 16),
                                      label: const Text('열기'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _green,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        textStyle: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => Share.shareXFiles(
                                          [XFile(_savedPath!)]),
                                      icon: const Icon(Icons.share, size: 16),
                                      label: const Text('공유'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _green,
                                        side: const BorderSide(
                                            color: _green, width: 1.2),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        textStyle: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StepCard(
                    step: '2',
                    title: '파일 선택',
                    subtitle: '여러 클럽 파일을 순서대로 올리면 자동 누적됩니다',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.folder_open_rounded),
                          label: const Text('엑셀 파일 선택'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (_fileName != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.insert_drive_file_rounded,
                                  size: 16, color: _blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_fileName!,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: _blue,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ),
                        ],
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 16, color: _red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_errorMsg!,
                                      style: const TextStyle(
                                          fontSize: 12, color: _red)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_warningMsg != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _warnBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _warnBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 16, color: _warnIcon),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_warningMsg!,
                                      style: const TextStyle(
                                          fontSize: 12, color: _warnText)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StepCard(
                    step: '3',
                    title: _preview.isNotEmpty
                        ? '미리보기 (${_preview.length}건)'
                        : '등록',
                    subtitle: _preview.isNotEmpty
                        ? '내용을 확인하고 등록 버튼을 눌러주세요'
                        : '파일을 선택하면 미리보기가 표시됩니다',
                    child: _preview.isNotEmpty
                        ? Column(children: [
                            Container(
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                        const Color(0xFFEFF6FF)),
                                    dataRowMinHeight: 36,
                                    dataRowMaxHeight: 44,
                                    headingRowHeight: 40,
                                    columnSpacing: 16,
                                    horizontalMargin: 12,
                                    columns: const [
                                      DataColumn(
                                          label: Text('이름',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _blue))),
                                      DataColumn(
                                          label: Text('소속클럽',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _blue))),
                                      DataColumn(
                                          label: Text('종목',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _blue))),
                                      DataColumn(
                                          label: Text('급수',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _blue))),
                                      DataColumn(
                                          label: Text('파트너',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _blue))),
                                      DataColumn(
                                          label: Text('파트너클럽',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _blue))),
                                    ],
                                    rows: _preview
                                        .take(5)
                                        .map((e) => DataRow(cells: [
                                              DataCell(Text(e.name,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _ink))),
                                              DataCell(Text(e.clubName,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _ink))),
                                              DataCell(Text(e.event,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _ink))),
                                              DataCell(Text(e.grade,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _ink))),
                                              DataCell(Text(e.partnerName,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _ink))),
                                              DataCell(Text(
                                                  e.partnerClubName ==
                                                          e.clubName
                                                      ? ''
                                                      : e.partnerClubName,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _ink))),
                                            ]))
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                            if (_preview.length > 5) ...[
                              const SizedBox(height: 6),
                              Text('외 ${_preview.length - 5}건 더 있습니다',
                                  style: const TextStyle(
                                      fontSize: 12, color: _muted),
                                  textAlign: TextAlign.center),
                            ],
                            const SizedBox(height: 12),
                            FractionallySizedBox(
                              widthFactor: 0.55,
                              child: ElevatedButton.icon(
                                onPressed: _uploaded ? null : _register,
                                icon: const Icon(Icons.cloud_upload_rounded),
                                label: Text('${_preview.length}건 등록하기'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      _green.withOpacity(0.4),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ])
                        : Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            alignment: Alignment.center,
                            child: const Column(children: [
                              Icon(Icons.table_chart_outlined,
                                  size: 36, color: _muted),
                              SizedBox(height: 8),
                              Text('파일을 선택해주세요',
                                  style:
                                      TextStyle(fontSize: 13, color: _muted)),
                            ]),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final Widget child;
  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD1D9E6), width: 1.2),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 1)),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(step,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                            height: 1.2)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: _subtitle,
                            fontWeight: FontWeight.w500,
                            height: 1.3)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

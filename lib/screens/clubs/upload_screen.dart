import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/club.dart';
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

/// 급수 라벨 정규화.
/// 사용자가 "A", "A급", "초심" 등으로 입력해도 "A조", "초심조" 로 자동 변환.
/// 매칭 실패시 trim 한 원본 반환.
String _normalizeGrade(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  final upper = s.toUpperCase().replaceAll(' ', '');
  // 영문 한 글자 단독 또는 'X조'/'X급' 패턴 (A/B/C/D/S/E 등 모두 포괄)
  final letterMatch = RegExp(r'^([A-Z])(조|급)?$').firstMatch(upper);
  if (letterMatch != null) return '${letterMatch.group(1)}조';
  if (s == '초심' || s == '초심조' || s == '초심자' || s == '입문' || s == '입문조') {
    return '초심조';
  }
  if (s == '자강' || s == '자강조') return '자강조';
  return s;
}

enum UploadType { club, player }

class UploadScreen extends StatefulWidget {
  final UploadType type;
  const UploadScreen({super.key, required this.type});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;
  String? _errorMsg;
  String? _warningMsg;
  List<Map<String, String>> _preview = [];
  String? _fileName;
  String? _savedPath;
  bool _uploaded = false;

  String get _title =>
      widget.type == UploadType.club ? '클럽 임원 업로드' : '클럽 회원 업로드';

  String get _assetPath => widget.type == UploadType.club
      ? 'assets/excel/클럽_임원_샘플.xlsx'
      : 'assets/excel/클럽_회원_샘플.xlsx';

  String get _sampleName =>
      widget.type == UploadType.club ? '클럽_임원_샘플.xlsx' : '클럽_회원_샘플.xlsx';

  // ── 헤더 정규화 (공백 제거, 별표 제거) ──────
  String _normalize(String s) =>
      s.replaceAll(' ', '').replaceAll('*', '').trim();

  // ── 키 매칭 헬퍼 ──────────────────────────
  String _getValue(Map<String, String> row, List<String> candidates) {
    for (final key in row.keys) {
      final normKey = _normalize(key);
      for (final candidate in candidates) {
        if (normKey == _normalize(candidate)) {
          return row[key] ?? '';
        }
      }
    }
    return '';
  }

  // ── 샘플 다운로드 ────────────────────────────
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
                const SizedBox(height: 10),
                const Text(
                  '💡 파일 앱(내 파일)에서 위 경로로 이동하시면 파일을 찾을 수 있습니다.',
                  style: TextStyle(fontSize: 12, color: _subtitle),
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

  // ── 파일 선택 & 파싱 ─────────────────────────
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

      // ── '클럽 임원 등록' 또는 '클럽 회원 등록' 시트 우선 ──
      xl.Sheet? sheet;
      final targetSheetName =
          widget.type == UploadType.club ? '클럽 임원 등록' : '클럽 회원 등록';

      for (final entry in excel.tables.entries) {
        if (entry.key.contains(targetSheetName) ||
            entry.key.contains(widget.type == UploadType.club ? '임원' : '회원')) {
          sheet = entry.value;
          break;
        }
      }

      // 못 찾으면 데이터가 가장 많은 시트
      if (sheet == null) {
        for (final s in excel.tables.values) {
          if (s.rows.length > 2) {
            sheet = s;
            break;
          }
        }
        sheet ??= excel.tables.values.first;
      }

      // ── 헤더 행 자동 탐지: 첫 5행 중 키워드가 가장 많은 행 ──
      int headerRowIdx = 1; // 기본 2행(index=1)
      int maxKeyword = 0;
      final keywords = widget.type == UploadType.club
          ? ['클럽명', '회장', '총무']
          : ['이름', '성별', '급수', '클럽'];

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

      // ── 데이터 행 (헤더 다음 행부터, '예시'는 제외) ──
      // 핵심 컬럼 인덱스 찾기 (클럽명 또는 이름)
      final coreKeyword = widget.type == UploadType.club ? '클럽명' : '이름';
      int coreIdx = -1;
      for (var j = 0; j < headers.length; j++) {
        if (_normalize(headers[j]).contains(coreKeyword)) {
          coreIdx = j;
          break;
        }
      }

      final rows = <Map<String, String>>[];

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

        // 핵심 컬럼(클럽명/이름)이 비어있으면 데이터 아님 → 건너뛰기
        if (coreIdx >= 0) {
          final coreVal = row.length > coreIdx
              ? row[coreIdx]?.value?.toString().trim() ?? ''
              : '';
          if (coreVal.isEmpty) continue;
        }

        rows.add(map);
      }

      if (rows.isEmpty) {
        setState(() {
          _errorMsg = '데이터가 없습니다. 샘플 양식에 맞게 입력했는지 확인해주세요.';
          _isLoading = false;
        });
        return;
      }

      // ── 검증: errors(차단) / warnings(허용) 분리 ──
      final errors = <String>[];
      final unregClubs = <String>{};
      int normalizedCount = 0;
      int badBirthCount = 0;
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (widget.type == UploadType.club) {
          if (_getValue(row, ['클럽명']).isEmpty) {
            errors.add('${i + 1}번째 데이터: 클럽명 필수');
          }
          if (_getValue(row, ['회장이름', '회장 이름']).isEmpty) {
            errors.add('${i + 1}번째 데이터: 회장 이름 필수');
          }
        } else {
          final clubName = _getValue(row, ['클럽명', '소속클럽명', '소속 클럽명']);
          final gender = _getValue(row, ['성별']);
          final gradeRaw = _getValue(row, ['급수']);
          final grade = _normalizeGrade(gradeRaw);
          final birthDate = _getValue(row, ['생년월일']);

          if (_getValue(row, ['이름']).isEmpty) {
            errors.add('${i + 1}번째 데이터: 이름 필수');
          }
          if (gender.isEmpty) {
            errors.add('${i + 1}번째 데이터: 성별 필수');
          } else if (gender != '남' && gender != '여') {
            errors.add("${i + 1}번째: 성별은 '남' 또는 '여' 만 가능");
          }
          if (gradeRaw.isEmpty) {
            errors.add('${i + 1}번째 데이터: 급수 필수');
          }
          // 경고: 생년월일 형식 이상 (6/8자리 아님) — 0세로 저장하고 진행
          if (birthDate.isNotEmpty) {
            final digits = birthDate.replaceAll(RegExp(r'\D'), '');
            if (digits.length != 6 && digits.length != 8) {
              badBirthCount++;
            }
          }

          // 경고: 클럽 미등록 (등록은 진행)
          if (clubName.isNotEmpty &&
              !SampleData.clubs.any((c) => c.name == clubName)) {
            unregClubs.add(clubName);
          }
          // 경고: 급수 자동 정규화
          if (gradeRaw.isNotEmpty && grade != gradeRaw) {
            normalizedCount++;
          }
        }
      }

      if (errors.isNotEmpty) {
        setState(() {
          _errorMsg = errors.take(5).join('\n') +
              (errors.length > 5 ? '\n외 ${errors.length - 5}건' : '');
          _isLoading = false;
        });
        return;
      }

      final warnings = <String>[];
      if (unregClubs.isNotEmpty) {
        final shown = unregClubs.take(3).join(', ');
        final extra =
            unregClubs.length > 3 ? ' 외 ${unregClubs.length - 3}곳' : '';
        warnings.add(
            "미등록 클럽 ${unregClubs.length}곳 ($shown$extra) — 클럽 ID 없이 저장됩니다");
      }
      if (normalizedCount > 0) {
        warnings.add('급수 자동 정규화 $normalizedCount건 (예: A → A조)');
      }
      if (badBirthCount > 0) {
        warnings.add('생년월일 형식 이상 $badBirthCount건 — 나이 0으로 저장 (수동 보정 필요)');
      }

      setState(() {
        _preview = rows;
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

  // ── 최종 등록 ────────────────────────────────
  void _register() {
    if (_preview.isEmpty) return;

    int added = 0;
    int skipped = 0;
    int clubMismatch = 0;

    if (widget.type == UploadType.club) {
      for (final row in _preview) {
        final name = _getValue(row, ['클럽명']);
        final exists = SampleData.clubs.any((c) => c.name == name);
        if (exists) {
          skipped++;
          continue;
        }
        final club = Club(
          id: 'club_${DateTime.now().millisecondsSinceEpoch}_$added',
          name: name,
          presidentName: _getValue(row, ['회장이름', '회장 이름']),
          presidentPhone: _getValue(row, ['회장연락처', '회장 연락처']),
          secretaryName: _getValue(row, ['총무이름', '총무 이름']),
          secretaryPhone: _getValue(row, ['총무연락처', '총무 연락처']),
          venue: _getValue(row, ['운동장소', '운동 장소']),
          practiceDay: _getValue(row, ['운동요일', '운동 요일', '요일']),
        );
        SampleData.clubs.add(club);
        added++;
      }
    } else {
      for (final row in _preview) {
        final name = _getValue(row, ['이름']);
        final clubName = _getValue(row, ['클럽명', '소속클럽명', '소속 클럽명']);
        final exists = SampleData.players
            .any((p) => p.name == name && p.clubName == clubName);
        if (exists) {
          skipped++;
          continue;
        }

        final bd = _getValue(row, ['생년월일']);
        final age = Player.calcAgeFromBirthDate(bd);

        final club =
            SampleData.clubs.where((c) => c.name == clubName).firstOrNull;
        if (club == null && clubName.isNotEmpty) clubMismatch++;

        final gradeRaw = _getValue(row, ['급수']);
        final normalizedGrade =
            _normalizeGrade(gradeRaw.isEmpty ? 'C조' : gradeRaw);

        final player = Player(
          id: 'player_${DateTime.now().millisecondsSinceEpoch}_$added',
          name: name,
          gender: _getValue(row, ['성별']).isEmpty ? '남' : _getValue(row, ['성별']),
          grade: normalizedGrade.isEmpty ? 'C조' : normalizedGrade,
          clubId: club?.id ?? '',
          clubName: clubName,
          phone: _getValue(row, ['전화번호', '연락처']),
          birthDate: bd,
          age: age,
          regNumber:
              '2026-${(SampleData.players.length + added + 1).toString().padLeft(4, '0')}',
        );
        SampleData.players.add(player);
        added++;
      }
    }

    setState(() => _uploaded = true);

    final lines = <String>['$added건 등록되었습니다.'];
    if (clubMismatch > 0) {
      lines.add(
          '클럽 미매칭 $clubMismatch건은 클럽 ID 없이 저장됨\n→ 클럽 등록 후 수동 연결 필요');
    }
    if (skipped > 0) {
      lines.add('(중복 $skipped건 건너뜀)');
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
        content: Text(
          lines.join('\n'),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
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
        title: Text(_title,
            style: const TextStyle(
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
                    subtitle: '양식에 맞게 데이터를 입력해주세요',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _downloadSample,
                          icon: const Icon(Icons.download_rounded),
                          label: Text('$_sampleName 다운로드'),
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        size: 16, color: _green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('저장 완료',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: _green)),
                                          const SizedBox(height: 2),
                                          Text(_savedPath!,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: _subtitle)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
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
                    subtitle: '작성 완료된 엑셀 파일을 선택해주세요 (.xlsx)',
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
                                    columns: _preview.first.keys
                                        .where((k) => k.isNotEmpty)
                                        .map((k) => DataColumn(
                                              label: Text(k,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: _blue,
                                                  )),
                                            ))
                                        .toList(),
                                    rows: _preview
                                        .take(5)
                                        .map((row) => DataRow(
                                              cells: row.entries
                                                  .where(
                                                      (e) => e.key.isNotEmpty)
                                                  .map((e) => DataCell(
                                                        Text(e.value,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color:
                                                                        _ink)),
                                                      ))
                                                  .toList(),
                                            ))
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

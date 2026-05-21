import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../models/bracket_models.dart';
import '../../models/match.dart';
import '../../models/match_score.dart';
import '../../models/player.dart';
import '../../models/tournament.dart';
import '../../models/venue.dart';
import '../../services/analytics_service.dart';
import '../../services/bracket_auth_stub.dart';
import '../../services/firestore/match_score_repo.dart';
import '../../services/firestore/player_repo.dart';
import '../../services/sample_data.dart';
import '../../services/storage_service.dart';
import '../../utils/age_group.dart';
import '../../utils/match_key.dart';
import '../../utils/bracket_logic.dart';
import '../../score/pages/scoreboard_page.dart';
import '../../widgets/bracket/bracket_generator_tab.dart';
import '../../widgets/common/filter_chips.dart';
import '../../widgets/players/player_list_item.dart';
import '../../widgets/signature_pad.dart';
import 'entry_upload_screen.dart';
import 'participant_add_screen.dart';
import 'signatures_page.dart';

const _headerInk = Color(0xFF0D1B3E);

// ═══════════════════════════════════════════════════════
//  BracketScreen
// ═══════════════════════════════════════════════════════
class BracketScreen extends StatefulWidget {
  final Tournament tournament;
  final int initialTabIndex;
  const BracketScreen({
    super.key,
    required this.tournament,
    this.initialTabIndex = 0,
  });

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tc;
  late Tournament _tournament;

  String _type = '혼복';
  // _activeAgeGroups / _openSections 의 원소는 ageGroup 라벨("20","45","전체"제외).
  final Set<String> _activeAgeGroups = {};
  final Set<String> _activeGrades = {};
  final Set<String> _openSections = {};
  final Set<String> _selected = {};

  /// '참가자 부족 시 인접 연령 자동 합치기' 스위치 (설정 탭).
  /// ON 이면 buildDivisions 전처리에서 같은 (종목·급수) 안의 인접 연령을 합쳐
  /// 각 셀이 최소 6명을 채우도록 함. 라벨은 '20·30' 처럼 가운뎃점 결합.
  bool _autoMergeAges = false;

  /// 점수판/수동입력에서 회수한 매치별 점수 + 팀 식별 정보.
  /// 키 빌드 로직은 `utils/match_key.dart` 공유 (위치 안정 ID).
  /// 페어 변경 시 옛 점수의 무효화는 [MatchScore.scoreFor] 의 set 비교로 처리.
  final Map<String, MatchScore> _matchScores = {};

  int _totalDays = 1;
  static const int _maxDays = 4;
  final _date1Ctrl = TextEditingController(text: '2026-05-10');
  final _date2Ctrl = TextEditingController(text: '2026-05-11');
  final _date3Ctrl = TextEditingController(text: '2026-05-12');
  final _date4Ctrl = TextEditingController(text: '2026-05-13');

  /// 일자별 종별. key=1~_maxDays. value=해당 일자의 종별 리스트(혼복/남복/여복).
  /// _tournament.eventType 은 모든 일자 합집합으로 자동 유지(레거시 호환).
  final Map<int, List<String>> _dayEvents = {};

  /// (일자, 종별)별 연령 선택. 1일차 남복 [20,30] / 2일차 남복 [40,50,60] 같은
  /// 비대칭 분할이 가능하다. 외부 키=1~_maxDays, 내부 키=종별(혼복/남복/여복).
  /// [_activeAgeGroups] 는 모든 (활성 일자, 활성 종별) 합집합으로 자동 유지.
  final Map<int, Map<String, Set<String>>> _dayEventAges = {};

  /// (일자, 종별)별 급수 선택. 의미·관리 정책은 [_dayEventAges] 와 동일.
  final Map<int, Map<String, Set<String>>> _dayEventGrades = {};

  /// 경기정보 카드에서 현재 선택된 일자(1-base, 1~_totalDays).
  int _selectedScheduleDay = 1;

  /// 일자별 (event, age, grade) → venueId 배정.
  /// 같은 (event, age, grade) 셀이라도 일자가 다르면 다른 경기장에 배정 가능.
  /// [_assignMap] 는 전 일자 공통 fallback 으로 남겨두고, 일자 칩 클릭/AI 자동배정은
  /// 이 맵을 우선 읽고 쓴다.
  final Map<int, Map<AssignKey, String>> _dayAssignMap = {};

  /// 일자별 비활성 경기장 ID 집합. 일자가 맵에 없거나 비어 있으면 그 일자에는 모든 경기장 활성.
  /// 대회날짜 카드에서 일자별 사용 경기장을 토글로 선택하면 여기 누적.
  final Map<int, Set<String>> _dayInactiveVenues = {};
  late List<Venue> _venues;
  final Map<AssignKey, String> _assignMap = {};
  Timer? _persistDebounce;
  Timer? _chipFiltersDebounce;
  Timer? _selectedDebounce;
  Timer? _scheduleDebounce;
  /// Firestore matches/{tid}/rounds 실시간 구독. 외부(점수판/콘솔/다른 기기) 변경 반영.
  StreamSubscription<Map<String, MatchScore>>? _matchScoresSub;
  /// 일정 하이드레이트 완료 플래그. controller listener 가 초기 로드 시점의
  /// `setText` 까지 saving 으로 판단해 무한 루프/덮어쓰기 발생하지 않도록 차단.
  bool _scheduleHydrated = false;
  static const int _maxCourtsPerVenue = 10;

  /// 참가신청 엑셀 업로드로 누적된 종목별 카운트.
  /// 비어있으면 BottomSheet 에 종목 요약 라인 미노출.
  Map<String, int> _entryEventCounts = const {};

  /// 사용자 정의 급수 (자강조 등). 표준 급수와 합쳐 칩으로 노출.
  List<String> _customGrades = const [];

  /// AI 자동배정 직전 _dayAssignMap[day] 스냅샷. 'AI 자동취소'로 해당 일자만 복원.
  /// null = 배정 후 한번도 자동배정 안 했거나 이미 취소함.
  /// day = 스냅샷이 어떤 일자에 대한 것인지 (다른 일자에서 취소 누르지 못하도록).
  ({int day, Map<AssignKey, String> snapshot})? _preAiAssignMap;

  /// "전체" 제외, 실제 연령 그룹 라벨 목록
  List<String> get _ageGroupLabels =>
      _tournament.ageGroups.where((l) => l != '전체').toList();

  /// "전체" 제외, 실제 급수 그룹 라벨 목록
  List<String> get _gradeGroupLabels =>
      _tournament.gradeGroups.where((l) => l != '전체').toList();

  void rebuild(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tournament = widget.tournament;
    _tc = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    // 기본 상태: 연령·급수 칩 모두 미선택, 참가자도 모두 미선택.
    // 사용자가 필요한 칩을 켠 뒤 참가자를 명시적으로 선택해야 대진표 대상이 됨.

    // venues 하이드레이트: 저장된 venues 가 있으면 사용, 없으면 기본 1개 생성.
    final stored = _tournament.venues;
    if (stored.isNotEmpty) {
      _venues = stored
          .asMap()
          .entries
          .map((e) => e.value.copyWith(
                id: e.value.id.isNotEmpty ? e.value.id : 'v${e.key + 1}',
                colorHex: e.value.colorHex.isNotEmpty
                    ? e.value.colorHex
                    : Venue.defaultColors[e.key % Venue.defaultColors.length],
              ))
          .toList();
      // 1회 보정: 사용자 요청대로 1번 경기장을 녹색(#2a7d4f) 으로. flag 가 없을 때만
      // 적용하고 즉시 flag 를 세팅 → 이후 picker 로 다른 색을 선택해도 강제 안 됨.
      _applyVenue1GreenOnce();
      _applyVenue2TealOnce();
    } else {
      _venues = [
        Venue(
          id: 'v1',
          name: '',
          address: '',
          courts: Tournament.defaultCourtsPerVenue,
          colorHex: Venue.defaultColors[0],
        ),
      ];
    }

    // 저장된 배정 복원: 각 셀에 대해 stored venueId 가 현재 _venues 에 존재하면 사용,
    // 아니면 첫 경기장으로 폴백. 셀이 stored map 에 없으면 첫 경기장.
    // 키 라벨은 UI 가 쓰는 _gradeGroupLabels (A조/B조/.../초심조 + 사용자 정의) 와 정확히
    // 일치해야 한다. (이전에 ['A','B','C','D','초심'] 하드코딩으로 키가 항상 어긋나
    // 첫 경기장으로 폴백되는 버그가 있었다.)
    final storedAssign = _tournament.assignMap;
    final liveVenueIds = _venues.map((v) => v.id).toSet();
    final fallbackVenueId = _venues.first.id;
    for (final ev in Tournament.allEventTypes) {
      for (final label in _ageGroupLabels) {
        for (final g in _gradeGroupLabels) {
          final stored = storedAssign[_assignStorageKey(ev, label, g)];
          _assignMap[AssignKey(ev, label, g)] =
              (stored != null && liveVenueIds.contains(stored))
                  ? stored
                  : fallbackVenueId;
        }
      }
    }

    // 일자별 종별 기본값: 모든 일자에 _tournament.eventTypeList 복사.
    // _loadSchedule 에서 저장값이 있으면 덮어쓴다.
    final defaultEvents = List.of(_tournament.eventTypeList);
    for (int d = 1; d <= _maxDays; d++) {
      _dayEvents[d] = List.of(defaultEvents);
    }

    _date1Ctrl.addListener(_onScheduleTextChanged);
    _date2Ctrl.addListener(_onScheduleTextChanged);
    _date3Ctrl.addListener(_onScheduleTextChanged);
    _date4Ctrl.addListener(_onScheduleTextChanged);

    _loadCustomGrades();
    _loadFilterType();
    _loadChipFilters();
    _loadAutoMergeAges();
    _loadSelectedPlayers();
    _loadSchedule();
    _loadDayInactiveVenues();
    _loadDayAssign();
    _loadEntryEventCounts();
    _loadMatchScores();

    // Firestore players 변경(다른 기기/콘솔) 시 명단 자동 리프레시.
    SampleData.playersRev.addListener(_onPlayersChanged);
  }

  /// Firestore stream 으로 들어온 외부 변경 반영. _selected 에서 사라진 id 도 정리.
  void _onPlayersChanged() {
    if (!mounted) return;
    final live = SampleData.players.map((p) => p.id).toSet();
    setState(() => _selected.removeWhere((id) => !live.contains(id)));
  }

  /// 마지막 매치별 점수 복원 (점수판/수동입력 결과).
  /// SP 캐시에서 즉시 띄우고, Firestore 가 비어 있으면 1회 시드 + 실시간 구독.
  Future<void> _loadMatchScores() async {
    final saved =
        await StorageService.loadBracketMatchScores(_tournament.id);
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _matchScores
          ..clear()
          ..addEntries(saved.entries
              .map((e) => MapEntry(e.key, MatchScore.fromJson(e.value))));
      });
    }
    // Firestore 서브컬렉션이 비어 있으면 SP 캐시값을 1회 업로드.
    // 이미 데이터가 있으면 no-op.
    final localCopy = Map<String, MatchScore>.from(_matchScores);
    if (localCopy.isNotEmpty) {
      try {
        await MatchScoreRepo.instance
            .seedFromLocalIfEmpty(_tournament.id, localCopy);
      } catch (e) {
        debugPrint('[BracketScreen] match score seed skipped: $e');
      }
    }
    // teamSig suffix 가 붙은 legacy doc 들 1회 정리 — 대회당 한 번.
    // (오늘 빌드 이전에 저장된 leak 문서들 청소.)
    final cleanupFlag = 'match_cleanup_v2_${_tournament.id}';
    if (!await StorageService.getFlag(cleanupFlag)) {
      try {
        final removed = await MatchScoreRepo.instance
            .cleanupLegacyDocs(_tournament.id);
        if (removed >= 0) {
          await StorageService.setFlag(cleanupFlag, true);
          debugPrint(
              '[BracketScreen] cleaned $removed legacy match docs for ${_tournament.id}');
        }
      } catch (e) {
        debugPrint('[BracketScreen] match cleanup skipped: $e');
      }
    }
    // teamA/teamB/createdBy 누락된 기존 doc 백필 — 대회당 한 번.
    final backfillFlag = 'match_backfill_v2_${_tournament.id}';
    if (!await StorageService.getFlag(backfillFlag)) {
      try {
        final lookup = _buildTeamLookup();
        final uid = await _resolveUid();
        if (!mounted) return;
        final n = await MatchScoreRepo.instance.backfillMissingFields(
          _tournament.id,
          (k) => lookup[k],
          fallbackCreatedBy: uid,
        );
        if (n >= 0) {
          await StorageService.setFlag(backfillFlag, true);
          debugPrint(
              '[BracketScreen] backfilled $n match docs for ${_tournament.id}');
        }
      } catch (e) {
        debugPrint('[BracketScreen] match backfill skipped: $e');
      }
    }
    // 실시간 구독 시작 — 다른 기기/콘솔에서 점수 변경 시 자동 반영.
    _matchScoresSub?.cancel();
    _matchScoresSub = MatchScoreRepo.instance
        .watchByTournament(_tournament.id)
        .listen((remote) {
      if (!mounted) return;
      // 단순 전체 교체. Firestore offline persistence 가 로컬 write 도 즉시
      // 스냅샷에 반영해 주므로 in-flight 충돌은 발생하지 않는다.
      setState(() {
        _matchScores
          ..clear()
          ..addAll(remote);
      });
      // SP 캐시도 같이 최신화 — 다음 콜드 부트 즉시 표시.
      final map = <String, Map<String, dynamic>>{};
      remote.forEach((k, v) {
        map[k] = v.toJson();
      });
      StorageService.saveBracketMatchScores(_tournament.id, map);
    }, onError: (e) {
      debugPrint('[BracketScreen] match score stream error: $e');
    });
  }

  /// 매치별 점수 저장. 호출자가 _matchScores 갱신 후 즉시 호출.
  /// SP 캐시 + Firestore dual-write. Firestore write 실패해도 SP 는 유지되어
  /// 다음 _saveMatchScores 또는 stream 으로 자가 치유.
  void _saveMatchScores() {
    final cache = <String, Map<String, dynamic>>{};
    _matchScores.forEach((k, v) {
      cache[k] = v.toJson();
    });
    StorageService.saveBracketMatchScores(_tournament.id, cache);
    final snapshot = Map<String, MatchScore>.from(_matchScores);
    MatchScoreRepo.instance
        .upsertMany(_tournament.id, snapshot)
        .catchError((e) {
      debugPrint('[BracketScreen] match score Firestore upsert failed: $e');
    });
    AnalyticsService.scoreSave(
      tournamentId: _tournament.id,
      totalMatches: snapshot.length,
    );
  }

  /// 디버그 메뉴 → 'Crashlytics 테스트 크래시'. 비치명 에러를 즉시 기록 (앱 안 죽음).
  /// Firebase Console → Crashlytics 에 5-10분 내 등장하면 연동 정상.
  /// Crashlytics 는 web 미지원이므로 그 경우 안내만.
  Future<void> _triggerTestCrash() async {
    final messenger = ScaffoldMessenger.of(context);
    if (kIsWeb) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Crashlytics 는 web 미지원입니다. 폰에서 시도해주세요.'),
      ));
      return;
    }
    // funminton 로컬 모드 — Firebase Crashlytics 미사용. 디버그 로그만 남김.
    debugPrint('[crashlytics-stub] test crash trigger ignored in local mode');
    messenger.showSnackBar(const SnackBar(
      content: Text('로컬 모드 — Crashlytics 비활성 상태입니다.'),
    ));
  }

  /// 운영 메뉴 → '서명 모음'. 현재 _matchScores 스냅샷을 들고
  /// SignaturesPage 로 push. 라이브 stream 은 부모 (BracketScreen) 에 유지.
  void _openSignaturesPage() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SignaturesPage(
        tournament: _tournament,
        matchScores: Map<String, MatchScore>.from(_matchScores),
      ),
    ));
  }

  /// 디버그 메뉴 → '매치 doc 백필 실행'. 자동 1회 실행과 동일 로직 + 플래그 무시.
  /// 결과는 SnackBar 로 보고. 콘솔에서 옛 docs (1·2·…) 가 모든 필드 채워졌는지 검증용.
  Future<void> _runMatchBackfillNow() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 1),
        content: Text('매치 doc 백필 시작…'),
      ),
    );
    try {
      final lookup = _buildTeamLookup();
      final uid = await _resolveUid();
      final n = await MatchScoreRepo.instance.backfillMissingFields(
        _tournament.id,
        (k) => lookup[k],
        fallbackCreatedBy: uid,
      );
      await StorageService.setFlag(
          'match_backfill_v2_${_tournament.id}', true);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.green2,
        content: Text('백필 완료 — $n 개 doc 업데이트'),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.red,
        content: Text('백필 실패: $e'),
      ));
    }
  }

  /// 백필용 lookup: doc key → 현재 페어 기준 팀 정보 담은 [MatchScore]
  /// (점수 0 / createdBy 빈 값). [MatchScoreRepo.backfillMissingFields] 에 넘긴다.
  Map<String, MatchScore> _buildTeamLookup() {
    final out = <String, MatchScore>{};
    for (final d in _tournament.divisions) {
      final fmt = d.format;
      for (int gi = 0; gi < fmt.groups.length; gi++) {
        final g = fmt.groups[gi];
        // 조별 팀 슬라이스 (_DivisionCard._teamsForGroup 와 동일 로직).
        int start = 0;
        for (int i = 0; i < gi; i++) {
          start += fmt.groups[i].size;
        }
        final end = (start + g.size).clamp(0, d.teams.length);
        if (start >= d.teams.length) continue;
        final teams = d.teams.sublist(
            start.clamp(0, d.teams.length), end);
        final matches = generateMatches(
          group: g,
          courts: 1, // 코트 수는 매치 인덱싱에 영향 없음.
        );
        for (final m in matches) {
          if (m.team1Index >= teams.length ||
              m.team2Index >= teams.length) continue;
          final t1 = teams[m.team1Index];
          final t2 = teams[m.team2Index];
          final key = matchScoreKey(
            event: d.event,
            age: d.ageGroup,
            grade: d.grade,
            groupName: g.name,
            matchNum: m.num_,
          );
          out[key] = MatchScore(
            key: key,
            scoreA: 0,
            scoreB: 0,
            teamA: List<String>.from(t1.playerIds),
            teamB: List<String>.from(t2.playerIds),
            teamANames: List<String>.from(t1.players),
            teamBNames: List<String>.from(t2.players),
            createdBy: '',
          );
        }
      }
    }
    return out;
  }

  /// 현재 로그인 uid (createdBy 필드용). 익명 계정도 uid 가 있음.
  /// 익명 자동 로그인이 아직 안 끝났으면 [AuthService.ensureSignedIn] 으로 대기 후 반환.
  Future<String> _resolveUid() async {
    final u = AuthService.instance.currentUser;
    if (u != null && u.uid.isNotEmpty) return u.uid;
    final signed = await AuthService.instance.ensureSignedIn();
    return signed?.uid ?? '';
  }

  /// 마지막 신청서 엑셀 누적 종목 카운트 복원.
  /// 저장값 없으면 빈 맵 유지(요약 라인 미노출).
  Future<void> _loadEntryEventCounts() async {
    final saved =
        await StorageService.loadBracketEntryEventCounts(_tournament.id);
    if (!mounted || saved == null) return;
    setState(() => _entryEventCounts = saved);
  }

  void _onScheduleTextChanged() {
    if (!_scheduleHydrated) return;
    _saveScheduleDebounced();
  }

  /// 마지막 참가자 탭 종별 필터(`_type`) 복원.
  /// 저장값이 없거나 알 수 없는 값이면 기본 `'혼복'` 유지.
  Future<void> _loadFilterType() async {
    final saved = await StorageService.loadBracketTypeFilter(_tournament.id);
    if (!mounted || saved == null) return;
    if (saved == '혼복' || saved == '남복' || saved == '여복') {
      setState(() => _type = saved);
    }
  }

  /// 마지막 연령/급수 칩 활성 상태 복원.
  /// - 저장값 없으면 initState 의 기본값(모두 활성) 유지
  /// - 저장값 있으면 현재 라벨과 교집합만 적용 (라벨 변경/삭제 대비)
  /// - `_openSections` 는 활성 연령에 맞춰 동기화 (개별 collapse 상태는 미영속화)
  Future<void> _loadChipFilters() async {
    final ages =
        await StorageService.loadBracketActiveAgeGroups(_tournament.id);
    final grades =
        await StorageService.loadBracketActiveGrades(_tournament.id);
    if (!mounted) return;
    setState(() {
      if (ages != null) {
        final live = _ageGroupLabels.toSet();
        final filtered = ages.where(live.contains).toList();
        _activeAgeGroups
          ..clear()
          ..addAll(filtered);
        _openSections
          ..clear()
          ..addAll(filtered);
      }
      if (grades != null) {
        final live = _gradeGroupLabels.toSet();
        _activeGrades
          ..clear()
          ..addAll(grades.where(live.contains));
      }
    });
  }

  /// 칩 활성 상태 저장 (디바운스 400ms). 빠른 연속 토글에 대응.
  void _saveChipFiltersDebounced() {
    _chipFiltersDebounce?.cancel();
    _chipFiltersDebounce = Timer(const Duration(milliseconds: 400), () {
      StorageService.saveBracketActiveAgeGroups(
          _tournament.id, _activeAgeGroups.toList());
      StorageService.saveBracketActiveGrades(
          _tournament.id, _activeGrades.toList());
    });
  }

  /// '자동 합치기' 스위치 상태 복원 (설정 탭).
  Future<void> _loadAutoMergeAges() async {
    final v =
        await StorageService.loadBracketAutoMergeAges(_tournament.id);
    if (!mounted) return;
    setState(() => _autoMergeAges = v);
  }

  /// '자동 합치기' 스위치 토글.
  void _toggleAutoMergeAges(bool v) {
    setState(() => _autoMergeAges = v);
    StorageService.saveBracketAutoMergeAges(_tournament.id, v);
  }

  /// 마지막 참가자 선택 복원 — Phase 2 부터 Firestore `tournamentIds` 가 source of truth.
  ///
  /// 1순위: SampleData.players 중 tournamentIds 에 자기 tid 가 있는 player IDs
  /// 2순위: 1순위가 비어 있으면 SP `_selected` (Phase 1 백필 안 한 옛 기기)
  ///
  /// Firestore stream 이 외부 변경을 emit 하면 `_onPlayersChanged` 가 정리.
  Future<void> _loadSelectedPlayers() async {
    final tid = _tournament.id;
    final live = SampleData.players.map((p) => p.id).toSet();
    final fromFirestore = SampleData.players
        .where((p) => p.tournamentIds.contains(tid))
        .map((p) => p.id)
        .toSet();
    if (fromFirestore.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _selected
          ..clear()
          ..addAll(fromFirestore);
      });
      return;
    }
    // Fallback: SP 캐시. Phase 1 백필 미실행 환경 대비.
    final saved = await StorageService.loadBracketSelectedPlayers(tid);
    if (!mounted || saved == null) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(saved.where(live.contains));
    });
  }

  /// SP 캐시 저장 (디바운스 400ms). Firestore tournamentIds 가 source of truth 라
  /// SP 는 오프라인 fallback 용. selection 헬퍼들이 자동 호출.
  void _saveSelectedDebounced() {
    _selectedDebounce?.cancel();
    _selectedDebounce = Timer(const Duration(milliseconds: 400), () {
      StorageService.saveBracketSelectedPlayers(
          _tournament.id, _selected.toList());
    });
  }

  // ── Selection 헬퍼 ─────────────────────────
  //
  // _selected 를 직접 modify 하지 말고 아래 헬퍼들로 라우팅. in-memory _selected +
  // Firestore tournamentIds + SP 캐시 3 source 가 헬퍼 1회 호출로 동기화된다.
  // Firestore write 는 fire-and-forget — 실패해도 다음 진입 시 SP 캐시로 복원,
  // arrayUnion/arrayRemove 가 idempotent 라 재시도 안전.

  /// _selected 에 [ids] 추가. 이미 들어 있는 건 제외. Firestore tournamentIds 에도 arrayUnion.
  void _addToSelection(Iterable<String> ids) {
    final newly = <String>[];
    for (final id in ids) {
      if (_selected.add(id)) newly.add(id);
    }
    if (newly.isEmpty) return;
    for (final id in newly) {
      PlayerRepo.instance
          .addToTournament(id, _tournament.id)
          .catchError((e) {
        debugPrint(
            '[BracketScreen] addToTournament failed for $id/${_tournament.id}: $e');
      });
    }
    _saveSelectedDebounced();
  }

  /// _selected 에서 [ids] 제거. tournamentIds 에서도 arrayRemove (선수 doc 자체는 유지).
  void _removeFromSelection(Iterable<String> ids) {
    final removed = <String>[];
    for (final id in ids) {
      if (_selected.remove(id)) removed.add(id);
    }
    if (removed.isEmpty) return;
    for (final id in removed) {
      PlayerRepo.instance
          .removeFromTournament(id, _tournament.id)
          .catchError((e) {
        debugPrint(
            '[BracketScreen] removeFromTournament failed for $id/${_tournament.id}: $e');
      });
    }
    _saveSelectedDebounced();
  }

  /// _selected 를 [newIds] 로 통째 교체. 차집합 계산 후 add/remove 동시 호출.
  /// 빈 리스트 전달 시 _selected 전체 비우기 (선수 doc 자체는 유지).
  /// 참가자 추가 화면에서 결과 반영 시 사용.
  void _replaceSelection(Iterable<String> newIds) {
    final newSet = newIds.toSet();
    final toAdd = newSet.difference(_selected);
    final toRemove = _selected.difference(newSet);
    _selected
      ..clear()
      ..addAll(newSet);
    for (final id in toAdd) {
      PlayerRepo.instance
          .addToTournament(id, _tournament.id)
          .catchError((_) {});
    }
    for (final id in toRemove) {
      PlayerRepo.instance
          .removeFromTournament(id, _tournament.id)
          .catchError((_) {});
    }
    _saveSelectedDebounced();
  }

  /// 마지막 대회 일정(`_totalDays` + 4개 날짜) 복원.
  /// - 저장값 없으면 field initializer 의 기본값(1일, 2026-05-10..13) 유지
  /// - 저장값 있으면 setState 로 적용
  /// 완료 후 `_scheduleHydrated` 플래그를 켜서 이후 controller 변경부터 저장 트리거.
  Future<void> _loadSchedule() async {
    final saved = await StorageService.loadBracketSchedule(_tournament.id);
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _totalDays = saved.totalDays.clamp(1, _maxDays);
        _selectedScheduleDay = _selectedScheduleDay.clamp(1, _totalDays);
        final dates = saved.dates;
        if (dates.isNotEmpty) _date1Ctrl.text = dates[0];
        if (dates.length > 1) _date2Ctrl.text = dates[1];
        if (dates.length > 2) _date3Ctrl.text = dates[2];
        if (dates.length > 3) _date4Ctrl.text = dates[3];
        // 일자별 종별 복원 — 알 수 없는 라벨은 필터링.
        saved.dayEvents.forEach((day, events) {
          if (day < 1 || day > _maxDays) return;
          final filtered = events
              .where(Tournament.allEventTypes.contains)
              .toList();
          _dayEvents[day] = filtered;
        });
        // (일자, 종별)별 연령/급수 복원 — 키 범위 검증만 (라벨은 동적 라벨 지원을 위해 그대로 보관).
        saved.dayEventAges.forEach((day, eventMap) {
          if (day < 1 || day > _maxDays) return;
          _dayEventAges[day] = {
            for (final e in eventMap.entries) e.key: Set<String>.from(e.value),
          };
        });
        saved.dayEventGrades.forEach((day, eventMap) {
          if (day < 1 || day > _maxDays) return;
          _dayEventGrades[day] = {
            for (final e in eventMap.entries) e.key: Set<String>.from(e.value),
          };
        });
      });
    }
    _scheduleHydrated = true;
  }

  /// 일정 저장 (디바운스 400ms). 키보드 입력 한 글자 단위로 폭주하지 않도록 묶음.
  void _saveScheduleDebounced() {
    _scheduleDebounce?.cancel();
    _scheduleDebounce = Timer(const Duration(milliseconds: 400), () {
      StorageService.saveBracketSchedule(
        _tournament.id,
        _totalDays,
        [
          _date1Ctrl.text,
          _date2Ctrl.text,
          _date3Ctrl.text,
          _date4Ctrl.text,
        ],
        dayEvents: _dayEvents,
        dayEventAges: _dayEventAges,
        dayEventGrades: _dayEventGrades,
      );
    });
  }

  // ── 일자별 사용 경기장 (대회날짜 카드) ─────────────
  /// 그 일자에 [venueId] 가 활성인지. 일자별 inactive 집합에 없으면 활성(기본).
  bool _isVenueActiveOnDay(int day, String venueId) {
    final inactive = _dayInactiveVenues[day];
    return inactive == null || !inactive.contains(venueId);
  }

  /// 그 일자에 사용 가능한 (courts > 0 + 활성) 경기장 목록.
  List<Venue> _venuesActiveOnDay(int day) => _venues
      .where((v) => v.courts > 0 && _isVenueActiveOnDay(day, v.id))
      .toList();

  /// 일자별 경기장 활성/비활성 토글. 최소 1개는 활성으로 남아야 함.
  void _toggleVenueOnDay(int day, String venueId) {
    final inactive = _dayInactiveVenues.putIfAbsent(day, () => <String>{});
    final wasInactive = inactive.contains(venueId);
    if (wasInactive) {
      setState(() {
        inactive.remove(venueId);
        if (inactive.isEmpty) _dayInactiveVenues.remove(day);
      });
    } else {
      final remaining = _venues
          .where((v) =>
              v.id != venueId &&
              v.courts > 0 &&
              !inactive.contains(v.id))
          .length;
      if (remaining < 1) return;
      setState(() => inactive.add(venueId));
    }
    StorageService.saveBracketDayInactiveVenues(
        _tournament.id, _dayInactiveVenues);
  }

  /// 일자별 셀 배정(_dayAssignMap) SP 영속화. AI 자동배정 / AssignTable 셀 탭 직후 호출.
  void _saveDayAssign() {
    final serialized = <int, Map<String, String>>{
      for (final e in _dayAssignMap.entries)
        e.key: {
          for (final c in e.value.entries)
            _assignStorageKey(c.key.event, c.key.decadeKey, c.key.grade):
                c.value,
        },
    };
    StorageService.saveBracketDayAssign(_tournament.id, serialized);
  }

  /// SP 에서 일자별 배정 복원. 화면 진입 시 1회 호출.
  Future<void> _loadDayAssign() async {
    final saved = await StorageService.loadBracketDayAssign(_tournament.id);
    if (!mounted || saved == null) return;
    setState(() {
      _dayAssignMap.clear();
      saved.forEach((day, m) {
        final inner = <AssignKey, String>{};
        m.forEach((sk, v) {
          final parts = sk.split('|');
          if (parts.length != 3) return;
          inner[AssignKey(parts[0], parts[1], parts[2])] = v;
        });
        if (inner.isNotEmpty) _dayAssignMap[day] = inner;
      });
    });
  }

  Future<void> _loadDayInactiveVenues() async {
    final saved =
        await StorageService.loadBracketDayInactiveVenues(_tournament.id);
    if (!mounted || saved == null) return;
    setState(() {
      _dayInactiveVenues.clear();
      _dayInactiveVenues.addAll(saved);
    });
  }

  /// 대진표 탭에 전달할 통합 배정 맵 — 플랫 [_assignMap] 위에 일자별
  /// [_dayAssignMap] 을 덮어쓴다. (셀 탭/AI 자동배정은 _dayAssignMap 에만 쓰는데
  /// BracketGeneratorTab 은 flat 만 읽어서 일자별 배정이 대진표에 안 보이던 문제 보정.)
  Map<AssignKey, String> get _effectiveAssignMap {
    final merged = Map<AssignKey, String>.from(_assignMap);
    for (int d = 1; d <= _totalDays; d++) {
      final dayMap = _dayAssignMap[d];
      if (dayMap != null) merged.addAll(dayMap);
    }
    return merged;
  }

  /// `_assignMap` 의 `AssignKey` 를 `Tournament.assignMap` 직렬화 키로 변환.
  /// 형식: `"<event>|<ageLabel>|<grade>"`. 분리자 `|` 는 라벨에 등장하지 않는다는 가정.
  static String _assignStorageKey(String event, String age, String grade) =>
      '$event|$age|$grade';

  Future<void> _loadCustomGrades() async {
    final saved = await StorageService.loadCustomGrades();
    if (!mounted) return;
    setState(() => _customGrades = saved);
  }

  /// 표준 + 사용자 정의 급수 (표시 순서 보존).
  List<String> get _allTargetGrades =>
      [...Tournament.allTargetGrades, ..._customGrades];

  /// `_dayEvents` 의 활성 일자(1~_totalDays) 합집합으로 `_tournament.eventType` 갱신.
  /// 합집합이 비면 갱신하지 않음(레거시 코드가 종별 1개 이상을 가정).
  /// 합집합이 기존 값과 같으면 persist 생략.
  void _recomputeUnionEventType() {
    final union = <String>{};
    for (int d = 1; d <= _totalDays; d++) {
      union.addAll(_dayEvents[d] ?? const <String>[]);
    }
    if (union.isEmpty) return;
    final ordered =
        Tournament.allEventTypes.where(union.contains).join(',');
    if (ordered == _tournament.eventType) return;
    _tournament = _tournament.copyWith(eventType: ordered);
    _persistTournament();
  }

  /// (day, event) 별 연령 Set 조회. 첫 호출 시 [_activeAgeGroups] 복사로 lazy 초기화
  /// — 일자별·종별 분기 전 기본값은 전역 활성 연령과 동일.
  Set<String> _dayEventAgesFor(int day, String event) {
    final dayMap = _dayEventAges.putIfAbsent(day, () => <String, Set<String>>{});
    return dayMap.putIfAbsent(event, () => Set<String>.from(_activeAgeGroups));
  }

  /// (day, event) 별 급수 Set 조회. 정책은 [_dayEventAgesFor] 와 동일.
  Set<String> _dayEventGradesFor(int day, String event) {
    final dayMap =
        _dayEventGrades.putIfAbsent(day, () => <String, Set<String>>{});
    return dayMap.putIfAbsent(event, () => Set<String>.from(_activeGrades));
  }

  /// (day, event) 맵의 합집합을 [_activeAgeGroups] / [_activeGrades] 에 반영.
  /// _dayEvents 의 활성 종별만 고려하여 사용 중인 라벨만 활성에 남도록 한다.
  void _resyncActiveFromDayMaps() {
    final ages = <String>{};
    final grades = <String>{};
    for (int d = 1; d <= _totalDays; d++) {
      final events = _dayEvents[d] ?? const <String>[];
      for (final e in events) {
        ages.addAll(_dayEventAges[d]?[e] ?? const <String>{});
        grades.addAll(_dayEventGrades[d]?[e] ?? const <String>{});
      }
    }
    _activeAgeGroups
      ..clear()
      ..addAll(ages);
    _activeGrades
      ..clear()
      ..addAll(grades);
  }

  /// (day, event) 단위 연령 칩 토글. _activeAgeGroups 는 합집합으로 자동 유지.
  void _toggleDayEventAge(int day, String event, String label) {
    final set = _dayEventAgesFor(day, event);
    setState(() {
      if (set.contains(label)) {
        set.remove(label);
      } else {
        set.add(label);
      }
      _resyncActiveFromDayMaps();
    });
    _saveChipFiltersDebounced();
    _saveScheduleDebounced();
  }

  /// (day, event) 단위 급수 칩 토글. 정책은 [_toggleDayEventAge] 와 동일.
  void _toggleDayEventGrade(int day, String event, String label) {
    final set = _dayEventGradesFor(day, event);
    setState(() {
      if (set.contains(label)) {
        set.remove(label);
      } else {
        set.add(label);
      }
      _resyncActiveFromDayMaps();
    });
    _saveChipFiltersDebounced();
    _saveScheduleDebounced();
  }

  /// 종별(혼복/남복/여복) 토글 — `_selectedScheduleDay` 일자만 변경.
  /// `_tournament.eventType` 은 활성 일자(1~_totalDays) 합집합으로 자동 유지.
  /// 합집합이 0개가 되는 토글은 무시(레거시 코드가 종별 1개 이상을 가정).
  void _toggleEvent(String e) {
    final day = _selectedScheduleDay.clamp(1, _maxDays);
    final cur = (_dayEvents[day] ?? const <String>[]).toSet();
    if (cur.contains(e)) {
      cur.remove(e);
    } else {
      cur.add(e);
    }
    final ordered =
        Tournament.allEventTypes.where(cur.contains).toList();

    // 합집합 계산 (이 일자는 ordered, 나머지 활성 일자는 기존 _dayEvents)
    final union = <String>{...ordered};
    for (int d = 1; d <= _totalDays; d++) {
      if (d == day) continue;
      union.addAll(_dayEvents[d] ?? const <String>[]);
    }
    if (union.isEmpty) return; // 전 일자 합집합이 비는 토글은 거부
    final unionOrdered =
        Tournament.allEventTypes.where(union.contains).join(',');

    setState(() {
      _dayEvents[day] = ordered;
      _tournament = _tournament.copyWith(eventType: unionOrdered);
    });
    _persistTournament();
    _saveScheduleDebounced();
  }

  /// 대상 급수 토글. 0개 허용 (저장 시 빈 문자열).
  void _toggleGrade(String g) {
    final cur = _tournament.targetGradeList.toSet();
    if (cur.contains(g)) {
      cur.remove(g);
    } else {
      cur.add(g);
    }
    final ordered =
        _allTargetGrades.where(cur.contains).join(',');
    setState(() {
      _tournament = _tournament.copyWith(targetGrade: ordered);
    });
    _persistTournament();
  }

  /// '전체' 마스터 토글: 모든 급수 ON ↔ 모두 OFF.
  void _toggleAllGrades() {
    final cur = _tournament.targetGradeList.toSet();
    final isAll = _allTargetGrades.every(cur.contains);
    final next = isAll ? '' : _allTargetGrades.join(',');
    setState(() {
      _tournament = _tournament.copyWith(targetGrade: next);
    });
    _persistTournament();
  }

  // ── Tournament 그룹 편집 ──────────────────────────
  /// `_tournament` 을 `SampleData.tournaments` 에 반영하고 SharedPreferences 에 저장.
  /// 저장 직전 `_assignMap` 을 직렬화하여 `_tournament.assignMap` 에 합쳐 한 번에 영속화.
  /// (이로써 모든 호출 지점이 자동으로 배정 상태까지 저장한다.)
  /// 운영자 입력 경기 시작 시각/소요 시간 갱신 후 저장(디바운스).
  /// time: "HH:mm" 형식. 유효하지 않으면 무시. minutes: 0 이상.
  /// 1일차 시작/휴식만 갱신할 때 사용. 2일차+는 [_updateDaySchedule] 사용.
  void _updateMatchTiming({
    String? startTime,
    int? durationMinutes,
    String? breakStartTime,
    int? breakDurationMinutes,
  }) {
    final next = _tournament.copyWith(
      matchStartTime: (startTime != null &&
              RegExp(r'^\d{1,2}:\d{2}$').hasMatch(startTime))
          ? startTime
          : null,
      matchDurationMinutes:
          (durationMinutes != null && durationMinutes >= 0)
              ? durationMinutes
              : null,
      breakStartTime: breakStartTime, // 빈 문자열도 유효(휴식 해제)
      breakDurationMinutes:
          breakDurationMinutes != null && breakDurationMinutes >= 0
              ? breakDurationMinutes
              : null,
    );
    rebuild(() => _tournament = next);
    _persistTournamentDebounced();
  }

  /// 일자별 경기시간 갱신. dayIdx 는 1-base.
  /// 1일차는 legacy 필드(matchStartTime/break*)로, 2일차+는 extraDaySchedules 로 저장.
  /// null 인 인자는 변경하지 않음. 휴식 해제는 [breakEnabled]=false 로.
  void _updateDaySchedule(
    int dayIdx, {
    String? startTime,
    bool? breakEnabled,
    String? breakStartTime,
    int? breakDurationMinutes,
  }) {
    final cur = _tournament.daySchedule(dayIdx);
    final nextDay = cur.copyWith(
      startTime: (startTime != null &&
              RegExp(r'^\d{1,2}:\d{2}$').hasMatch(startTime))
          ? startTime
          : null,
      breakEnabled: breakEnabled,
      breakStartTime: breakStartTime,
      breakDurationMinutes:
          (breakDurationMinutes != null && breakDurationMinutes >= 0)
              ? breakDurationMinutes
              : null,
    );
    if (dayIdx <= 1) {
      // 1일차는 legacy 필드로 저장. breakEnabled=false 면 break 값 클리어.
      final useBreak = nextDay.breakEnabled;
      rebuild(() {
        _tournament = _tournament.copyWith(
          matchStartTime: nextDay.startTime,
          breakStartTime: useBreak ? nextDay.breakStartTime : '',
          breakDurationMinutes:
              useBreak ? nextDay.breakDurationMinutes : 0,
        );
      });
    } else {
      // 2일차+는 extraDaySchedules 의 (dayIdx-2) 위치에 저장. 부족하면 패딩.
      final list = List<DaySchedule>.from(_tournament.extraDaySchedules);
      final target = dayIdx - 2;
      while (list.length <= target) {
        list.add(const DaySchedule());
      }
      list[target] = nextDay;
      rebuild(() {
        _tournament = _tournament.copyWith(extraDaySchedules: list);
      });
    }
    _persistTournamentDebounced();
  }

  void _persistTournament() {
    final serialized = <String, String>{};
    _assignMap.forEach((k, v) {
      serialized[_assignStorageKey(k.event, k.decadeKey, k.grade)] = v;
    });
    _tournament = _tournament.copyWith(assignMap: serialized);
    final idx = SampleData.tournaments.indexWhere((t) => t.id == _tournament.id);
    if (idx >= 0) {
      SampleData.tournaments[idx] = _tournament;
    }
    // SP + Firestore dual write 경유. fire-and-forget — debounce 위에서 호출됨.
    SampleData.saveTournaments();
  }

  void _persistTournamentDebounced() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(
      const Duration(milliseconds: 500),
      _persistTournament,
    );
  }

  // ── Venue 편집 ──────────────────────────────────
  /// _venues 와 _tournament.venues 를 동기화 후 저장 (디바운스).
  void _syncVenuesToTournament({bool debounce = true}) {
    _tournament =
        _tournament.copyWith(venues: _venues.map((v) => v.copyWith()).toList());
    if (debounce) {
      _persistTournamentDebounced();
    } else {
      _persistTournament();
    }
  }

  void _updateVenueName(int i, String name) {
    if (i < 0 || i >= _venues.length) return;
    _venues[i] = _venues[i].copyWith(name: name);
    _syncVenuesToTournament();
    if (mounted) setState(() {});
  }

  void _updateVenueAddress(int i, String address) {
    if (i < 0 || i >= _venues.length) return;
    _venues[i] = _venues[i].copyWith(address: address);
    _syncVenuesToTournament();
  }

  void _updateVenueCourts(int i, int courts) {
    if (i < 0 || i >= _venues.length) return;
    final clamped = courts.clamp(0, _maxCourtsPerVenue);
    if (_venues[i].courts == clamped) return;
    setState(() {
      _venues[i] = _venues[i].copyWith(courts: clamped);
      _syncVenuesToTournament(debounce: false);
    });
  }

  /// 1회성 보정: 1번 경기장 색을 녹색(#2a7d4f) 으로 한 번만 변경. flag 로 가드.
  /// (flag 가 이미 true 면 사용자가 picker 로 골랐을 색을 덮어쓰지 않는다.)
  Future<void> _applyVenue1GreenOnce() async {
    if (_venues.isEmpty) return;
    final applied = await StorageService.getFlag('venue_v1_green_applied');
    if (applied) return;
    if (!mounted) return;
    setState(() {
      _venues[0] = _venues[0].copyWith(colorHex: '#2a7d4f');
    });
    _syncVenuesToTournament(debounce: false);
    await StorageService.setFlag('venue_v1_green_applied', true);
  }

  /// 1회성 보정: 2번 경기장 색을 짙은 청록빛 파란색(#06618f) 으로.
  Future<void> _applyVenue2TealOnce() async {
    if (_venues.length < 2) return;
    final applied = await StorageService.getFlag('venue_v2_teal_applied');
    if (applied) return;
    if (!mounted) return;
    setState(() {
      _venues[1] = _venues[1].copyWith(colorHex: '#06618f');
    });
    _syncVenuesToTournament(debounce: false);
    await StorageService.setFlag('venue_v2_teal_applied', true);
  }

  void _updateVenueColor(int i, String colorHex) {
    if (i < 0 || i >= _venues.length) return;
    if (_venues[i].colorHex == colorHex) return;
    setState(() {
      _venues[i] = _venues[i].copyWith(colorHex: colorHex);
      _syncVenuesToTournament(debounce: false);
    });
  }

  /// 새 경기장 1개 추가. 기본 4코트, 색상은 `Venue.defaultColors` 순환.
  void _addVenue() {
    final id = 'v${DateTime.now().millisecondsSinceEpoch}';
    final color =
        Venue.defaultColors[_venues.length % Venue.defaultColors.length];
    setState(() {
      _venues.add(Venue(
        id: id,
        name: '',
        address: '',
        courts: 4,
        colorHex: color,
      ));
      _syncVenuesToTournament(debounce: false);
    });
  }

  /// AI 자동 배정: 체육관별 종료 시각이 최대한 가까워지도록 (event, age, grade) 셀을 분산.
  ///
  /// 시간 추정 — 단순 매치수/코트수 가 아닌, 실제 스케줄러 제약을 반영:
  ///  - **같은 급수만 동시 진행** (grade gate) → 한 체육관 = 급수별 시간의 **합**.
  ///  - **선수 매치 사이 1슬롯 휴식** → 풀리그 N팀 = `2(N-1)-1` 슬롯 이상.
  ///  - 코트 수 제약 → matches/courts 이상.
  ///  - 큰 급수는 다중 풀로 쪼개지므로 라운드 상한을 5로 cap.
  ///
  /// 알고리즘:
  ///  1) 모든 (event, age, grade) 셀의 매치 수 산출.
  ///  2) 급수 단위 LPT — 큰 급수부터 시뮬레이션 시간이 가장 작은 체육관에 통째 배정.
  ///  3) 재조정 — 최대 부하 체육관의 가장 작은 셀을 다른 체육관으로 옮기는 게 makespan
  ///     을 줄이면 반복. 임계값: matchMin 1슬롯 미만.
  ///
  /// 실행 전 스냅샷을 `_preAiAssignMap` 에 저장하여 'AI 자동취소'로 복원 가능.
  void _aiAssignVenues() {
    if (_venues.isEmpty) return;
    // 경기정보 카드의 현재 일자(_selectedScheduleDay) 셀만 처리.
    // 일자별 배정 맵에 쓰므로 다른 일자의 배정은 절대 영향 없음.
    final day = _selectedScheduleDay.clamp(1, _totalDays);
    // 그 일자에 사용 활성화된 경기장만 후보 (대회날짜 카드의 사용 경기장 토글 반영).
    final activeVs = _venues
        .where((v) =>
            v.courts > 0 && _isVenueActiveOnDay(day, v.id))
        .toList();
    if (activeVs.isEmpty) return;

    // 직전 그 일자 맵 스냅샷 (AI 자동취소용).
    final dayCurrent = _dayAssignMap[day] ?? const <AssignKey, String>{};
    final snapshot = Map<AssignKey, String>.from(dayCurrent);

    final selectedPlayers = SampleData.players
        .where((p) => _selected.contains(p.id))
        .toList();
    final selectedEvents = (_dayEvents[day] ?? const <String>[])
        .where(Tournament.allEventTypes.contains)
        .toList();

    // 1) 그 일자의 (event, age, grade) 셀 매치 수/그룹 수 산출.
    //    모든 (event, age, grade) 조합을 포함 — 매치가 안 만들어지는 셀(팀 3개 미만)도
    //    matches=0 으로 포함해서 AssignTable 의 시각 균등성을 유지한다. (이전: skip 으로
    //    인해 그 셀들이 모두 venue 1 기본값으로 남아 쏠림 현상 발생.)
    final allCells =
        <({String event, String age, String grade, int matches, int groups})>[];
    for (final ev in selectedEvents) {
      bool genderOk(Player p) {
        if (ev == '남복') return p.gender == '남';
        if (ev == '여복') return p.gender == '여';
        return true; // 혼복
      }
      final eventAges =
          _ageGroupLabels.where(_dayEventAgesFor(day, ev).contains).toList();
      final eventGrades = _gradeGroupLabels
          .where(_dayEventGradesFor(day, ev).contains)
          .toList();
      for (final age in eventAges) {
        for (final g in eventGrades) {
          final pool = selectedPlayers
              .where(genderOk)
              .where((p) => p.grade == g)
              .where((p) => ageMatches(age, p.age, _ageGroupLabels))
              .toList();
          final teams = pool.length ~/ 2;
          int matches = 0;
          int groups = 1;
          if (teams >= 3) {
            final fmt = determineFormat(teams);
            if (fmt != null) {
              for (final grp in fmt.groups) {
                if (grp.size >= 2) {
                  matches += (grp.size * (grp.size - 1)) ~/ 2;
                }
              }
              groups = fmt.groups.length;
            }
          }
          allCells.add((
            event: ev,
            age: age,
            grade: g,
            matches: matches,
            groups: groups,
          ));
        }
      }
    }

    if (allCells.isEmpty) return;

    // 핵심 메트릭: 경기장 부하 = 배정된 셀의 총 매치 수.
    // 균등성은 매치 수 ÷ 코트 수 (load per court) 가 모든 경기장에서 비슷한 것.
    final venueMatches = <String, int>{
      for (final v in activeVs) v.id: 0,
    };
    final venueCells = <String, List<int>>{
      for (final v in activeVs) v.id: <int>[],
    };
    final venueAges = <String, Set<String>>{
      for (final v in activeVs) v.id: <String>{},
    };

    Venue venueOf2(List<Venue> list, String id) =>
        list.firstWhere((x) => x.id == id);

    // venueCells 기준으로 venueAges 재구축 — swap/move 시 호출.
    void rebuildAgesSets() {
      for (final v in activeVs) {
        final set = venueAges[v.id]!;
        set.clear();
        for (final idx in venueCells[v.id]!) {
          set.add(allCells[idx].age);
        }
      }
    }

    // 경기장 부하 점수 — 작을수록 한산. 코트 수 가중 (코트 많은 경기장은 더 많은 매치 흡수).
    double loadPerCourt(String vid, [int addMatches = 0]) {
      final v = venueOf2(activeVs, vid);
      return (venueMatches[vid]! + addMatches) / v.courts;
    }

    double makespanPerCourt() {
      double m = 0;
      for (final v in activeVs) {
        final l = loadPerCourt(v.id);
        if (l > m) m = l;
      }
      return m;
    }

    // 2) LPT 배정 — 매치 수 큰 셀부터 가장 한산한 경기장 (loadPerCourt 최소) 에 배정.
    //    이 알고리즘은 grade-gate 같은 시간 amortization 을 무시 — 매치 수 균등이 우선.
    //    Tie 발생 시 같은 급수가 이미 있는 경기장을 약하게 선호 (locality, 운영 효율 ↑).
    final cellOrder = List<int>.generate(allCells.length, (i) => i)
      ..sort((a, b) =>
          allCells[b].matches.compareTo(allCells[a].matches));

    // 점수 메트릭 — 작을수록 선호.
    // PRIMARY: (셀 카운트 + 이 셀) / 코트 수 — 시각 균등성 (AssignTable 의 다크 칩 수 균등).
    //          7:6:4 코트면 10:9:6 셀로 비례 분산.
    // SECONDARY: 매치 수 가중치 (0.0001) — 시간 makespan tie-break.
    // TERTIARY: 같은 급수 locality (-0.00001) — 같은 경기장에 같은 급수면 약한 선호.
    double cellScore(String vid, int addMatches, String grade) {
      final newCount = venueCells[vid]!.length + 1;
      final courts = venueOf2(activeVs, vid).courts;
      final countRatio = newCount / courts;
      final matchTerm = (venueMatches[vid]! + addMatches) * 0.0001;
      final hasGrade =
          venueCells[vid]!.any((idx) => allCells[idx].grade == grade);
      final localityTerm = hasGrade ? -0.00001 : 0.0;
      return countRatio + matchTerm + localityTerm;
    }

    final cellVenue = <int, String>{};
    for (final i in cellOrder) {
      final c = allCells[i];
      String best = activeVs.first.id;
      double bestScore = cellScore(best, c.matches, c.grade);
      for (final v in activeVs.skip(1)) {
        final s = cellScore(v.id, c.matches, c.grade);
        if (s < bestScore - 1e-9) {
          bestScore = s;
          best = v.id;
        }
      }
      cellVenue[i] = best;
      venueMatches[best] = venueMatches[best]! + c.matches;
      venueCells[best]!.add(i);
      venueAges[best]!.add(c.age);
    }

    // 3) SWAP 재조정 — 가장 부하 큰 경기장과 가장 한산한 경기장 사이에서 두 셀을 교환해
    //    makespanPerCourt 가 감소하면 채택. 반복 200회.
    void swapCells(int i, int j) {
      final fromV = cellVenue[i]!;
      final toV = cellVenue[j]!;
      final ci = allCells[i];
      final cj = allCells[j];
      // 매치 수 갱신
      venueMatches[fromV] = venueMatches[fromV]! - ci.matches + cj.matches;
      venueMatches[toV] = venueMatches[toV]! - cj.matches + ci.matches;
      // 셀 목록 갱신
      venueCells[fromV]!.remove(i);
      venueCells[fromV]!.add(j);
      venueCells[toV]!.remove(j);
      venueCells[toV]!.add(i);
      cellVenue[i] = toV;
      cellVenue[j] = fromV;
      // 연령 셋 갱신
      rebuildAgesSets();
    }

    // 3) SWAP 재조정 — 셀 카운트 ÷ 코트 수 가 가장 큰 경기장과 가장 작은 경기장 사이
    //    MOVE/SWAP 으로 imbalance 줄이기. LPT 와 같은 메트릭 사용.
    double cellRatio(String vid) =>
        venueCells[vid]!.length / venueOf2(activeVs, vid).courts;

    for (int iter = 0; iter < 200; iter++) {
      String maxV = activeVs.first.id;
      String minV = activeVs.first.id;
      for (final v in activeVs) {
        if (cellRatio(v.id) > cellRatio(maxV)) maxV = v.id;
        if (cellRatio(v.id) < cellRatio(minV)) minV = v.id;
      }
      final imbalance = cellRatio(maxV) - cellRatio(minV);
      // 1셀 차이 미만이면 종료 (작은 경기장 기준 코트 수로 환산).
      if (imbalance < 1.0 / venueOf2(activeVs, minV).courts) break;

      // (A) MOVE: maxV 의 한 셀을 minV 로 이동. 셀 카운트 ratio 가 감소되면 채택.
      int? bestMoveIdx;
      double bestMoveImbalance = imbalance;
      for (final idx in venueCells[maxV]!) {
        final newMaxCount =
            (venueCells[maxV]!.length - 1) / venueOf2(activeVs, maxV).courts;
        final newMinCount =
            (venueCells[minV]!.length + 1) / venueOf2(activeVs, minV).courts;
        double maxR = newMaxCount;
        double minR = newMinCount;
        for (final v in activeVs) {
          if (v.id == maxV || v.id == minV) continue;
          final r = cellRatio(v.id);
          if (r > maxR) maxR = r;
          if (r < minR) minR = r;
        }
        final newImb = maxR - minR;
        if (newImb < bestMoveImbalance - 1e-9) {
          bestMoveImbalance = newImb;
          bestMoveIdx = idx;
        }
      }

      if (bestMoveIdx != null) {
        final c = allCells[bestMoveIdx];
        venueMatches[maxV] = venueMatches[maxV]! - c.matches;
        venueMatches[minV] = venueMatches[minV]! + c.matches;
        venueCells[maxV]!.remove(bestMoveIdx);
        venueCells[minV]!.add(bestMoveIdx);
        cellVenue[bestMoveIdx] = minV;
        rebuildAgesSets();
      } else {
        break;
      }
    }

    // 4) 일자별 배정 맵에 반영. allCells (활성 셀) 만 덮어쓴다.
    //    다른 일자의 _dayAssignMap[otherDay] 엔트리는 절대 건드리지 않음.
    final dayMap =
        Map<AssignKey, String>.from(_dayAssignMap[day] ?? const {});
    for (int i = 0; i < allCells.length; i++) {
      final c = allCells[i];
      dayMap[AssignKey(c.event, c.age, c.grade)] = cellVenue[i]!;
    }

    setState(() {
      _dayAssignMap[day] = dayMap;
      _preAiAssignMap = (day: day, snapshot: snapshot);
    });
    _persistTournament();
    _saveDayAssign();
  }

  /// AI 자동배정을 실행 직전 상태로 되돌림. 스냅샷이 기록된 일자만 복원.
  /// `_preAiAssignMap` 이 null 이면(스냅샷 없음) 무시.
  void _undoAiAssign() {
    final snap = _preAiAssignMap;
    if (snap == null) return;
    setState(() {
      if (snap.snapshot.isEmpty) {
        _dayAssignMap.remove(snap.day);
      } else {
        _dayAssignMap[snap.day] =
            Map<AssignKey, String>.from(snap.snapshot);
      }
      _preAiAssignMap = null;
    });
    _persistTournament();
    _saveDayAssign();
  }

  /// 현재 일자(_selectedScheduleDay) 의 모든 셀을 첫 경기장으로 재설정.
  /// 다른 일자의 배정은 그대로 유지. AI 자동배정 스냅샷도 초기화.
  void _resetAssignMap() {
    if (_venues.isEmpty) return;
    final day = _selectedScheduleDay.clamp(1, _totalDays);
    final fallbackId = _venues.first.id;
    setState(() {
      final dayMap = <AssignKey, String>{};
      for (final ev in Tournament.allEventTypes) {
        for (final label in _ageGroupLabels) {
          for (final g in _gradeGroupLabels) {
            dayMap[AssignKey(ev, label, g)] = fallbackId;
          }
        }
      }
      _dayAssignMap[day] = dayMap;
      _preAiAssignMap = null;
    });
    _persistTournament();
    _saveDayAssign();
  }

  /// 경기장 삭제. 마지막 1개는 삭제 불가(최소 1개 유지).
  /// 해당 경기장에 배정된 (연령,급수)는 첫 번째 남은 경기장으로 재배정.
  void _removeVenue(int i) {
    if (i < 0 || i >= _venues.length) return;
    if (_venues.length <= 1) return;
    final removedId = _venues[i].id;
    setState(() {
      _venues.removeAt(i);
      final fallbackId = _venues.first.id;
      _assignMap.updateAll(
          (key, val) => val == removedId ? fallbackId : val);
      _syncVenuesToTournament(debounce: false);
    });
  }

  void _addAgeGroup(String label) {
    final masterOn =
        _ageGroupLabels.isNotEmpty &&
            _ageGroupLabels.every(_activeAgeGroups.contains);
    setState(() {
      // 새 라벨 추가 후 나이 순(숫자 오름차순) 재정렬.
      // '전체'는 맨 앞 고정. 숫자 라벨은 오름차순. 텍스트 라벨은 숫자 뒤에 기존 상대 순서 유지.
      final combined = [..._tournament.ageGroups, label];
      final hasAll = combined.remove('전체');
      final numeric = <String>[];
      final textual = <String>[];
      for (final l in combined) {
        if (int.tryParse(l) != null) {
          numeric.add(l);
        } else {
          textual.add(l);
        }
      }
      numeric.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      _tournament = _tournament
          .copyWith(ageGroups: [if (hasAll) '전체', ...numeric, ...textual]);
      if (masterOn) {
        _activeAgeGroups.add(label);
        _openSections.add(label);
      }
      for (final ev in Tournament.allEventTypes) {
        for (final g in _gradeGroupLabels) {
          _assignMap[AssignKey(ev, label, g)] = _venues.first.id;
        }
      }
    });
    _persistTournament();
    _saveChipFiltersDebounced();
  }

  void _removeAgeGroup(String label) {
    setState(() {
      _tournament = _tournament.copyWith(
          ageGroups:
              _tournament.ageGroups.where((l) => l != label).toList());
      _activeAgeGroups.remove(label);
      _openSections.remove(label);
      _assignMap.removeWhere((k, _) => k.decadeKey == label);
    });
    _persistTournament();
    _saveChipFiltersDebounced();
  }

  /// 급수 정렬 순서: 자강조 → S조 → A조 → B조 → C조 → D조 → E조 → 초심조.
  /// 알 수 없는 라벨은 표 뒤(원래 순서 유지) — '전체'는 항상 맨 앞.
  static const Map<String, int> _gradeGroupSortOrder = {
    '자강조': 0,
    'S조': 1,
    'A조': 2,
    'B조': 3,
    'C조': 4,
    'D조': 5,
    'E조': 6,
    '초심조': 7,
  };

  void _addGradeGroup(String label) {
    final masterOn =
        _gradeGroupLabels.isNotEmpty &&
            _gradeGroupLabels.every(_activeGrades.contains);
    setState(() {
      // 새 라벨 추가 후 표준 급수 순서로 재정렬.
      // '전체'는 맨 앞, 표에 있는 급수는 정해진 순서, 그 외는 표 뒤에 기존 상대 순서 유지.
      final combined = [..._tournament.gradeGroups, label];
      final hasAll = combined.remove('전체');
      final known = <String>[];
      final unknown = <String>[];
      for (final l in combined) {
        if (_gradeGroupSortOrder.containsKey(l)) {
          known.add(l);
        } else {
          unknown.add(l);
        }
      }
      known.sort((a, b) =>
          _gradeGroupSortOrder[a]!.compareTo(_gradeGroupSortOrder[b]!));
      _tournament = _tournament
          .copyWith(gradeGroups: [if (hasAll) '전체', ...known, ...unknown]);
      if (masterOn) _activeGrades.add(label);
    });
    _persistTournament();
    _saveChipFiltersDebounced();
  }

  void _removeGradeGroup(String label) {
    setState(() {
      _tournament = _tournament.copyWith(
          gradeGroups:
              _tournament.gradeGroups.where((l) => l != label).toList());
      _activeGrades.remove(label);
    });
    _persistTournament();
    _saveChipFiltersDebounced();
  }

  /// 선수 한 명을 명단에서 영구 삭제. SampleData 헬퍼가 Firestore + SP 동시 삭제.
  /// player doc 자체가 사라지므로 tournamentIds 동기화 별도 호출 불필요.
  void _removePlayer(String id) {
    setState(() {
      _selected.remove(id);
    });
    SampleData.deletePlayer(id);
    _saveSelectedDebounced();
  }

  /// 모든 선수를 명단에서 영구 삭제. 모든 대회의 참가자 선택도 함께 비워짐.
  void _clearAllPlayers() {
    setState(() {
      _selected.clear();
    });
    SampleData.clearAllPlayers();
    _saveSelectedDebounced();
  }


  /// 디바이스 회전 등 metrics 변경 시 강제 리빌드 — TabBar 등 stale 레이아웃 갱신.
  /// (점수판에서 복귀할 때 landscape→portrait 전환이 자동 반영되지 않는 문제 보정.)
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SampleData.playersRev.removeListener(_onPlayersChanged);
    WidgetsBinding.instance.removeObserver(this);
    _matchScoresSub?.cancel();
    _persistDebounce?.cancel();
    if (_persistDebounce != null) {
      // 디바운스 대기 중인 변경사항 즉시 저장
      _persistTournament();
    }
    if (_chipFiltersDebounce?.isActive ?? false) {
      _chipFiltersDebounce!.cancel();
      // 디바운스 대기 중인 칩 상태 즉시 저장
      StorageService.saveBracketActiveAgeGroups(
          _tournament.id, _activeAgeGroups.toList());
      StorageService.saveBracketActiveGrades(
          _tournament.id, _activeGrades.toList());
    }
    if (_selectedDebounce?.isActive ?? false) {
      _selectedDebounce!.cancel();
      // 디바운스 대기 중인 참가자 선택 즉시 저장
      StorageService.saveBracketSelectedPlayers(
          _tournament.id, _selected.toList());
    }
    if (_scheduleDebounce?.isActive ?? false) {
      _scheduleDebounce!.cancel();
      // 디바운스 대기 중인 일정 즉시 저장
      StorageService.saveBracketSchedule(
        _tournament.id,
        _totalDays,
        [
          _date1Ctrl.text,
          _date2Ctrl.text,
          _date3Ctrl.text,
          _date4Ctrl.text,
        ],
        dayEvents: _dayEvents,
        dayEventAges: _dayEventAges,
        dayEventGrades: _dayEventGrades,
      );
    }
    _date1Ctrl.removeListener(_onScheduleTextChanged);
    _date2Ctrl.removeListener(_onScheduleTextChanged);
    _date3Ctrl.removeListener(_onScheduleTextChanged);
    _date4Ctrl.removeListener(_onScheduleTextChanged);
    _tc.dispose();
    _date1Ctrl.dispose();
    _date2Ctrl.dispose();
    _date3Ctrl.dispose();
    _date4Ctrl.dispose();
    super.dispose();
  }

  List<Player> get _filteredPlayers {
    var list = SampleData.players;
    if (_type == '남복') {
      list = list.where((p) => p.gender == '남').toList();
    } else if (_type == '여복') {
      list = list.where((p) => p.gender == '여').toList();
    }
    // 활성 연령 그룹 중 하나라도 매칭되어야 통과
    list = list
        .where((p) => _activeAgeGroups
            .any((l) => ageMatches(l, p.age, _ageGroupLabels)))
        .toList();
    list = list.where((p) => _activeGrades.contains(p.grade)).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // 점수판 종료 후 portrait 회전 transient frame 에 BracketScreen 이 landscape
    // constraint 를 받아 어디서든 RenderFlex overflow 발생 — painting 자체 skip 해
    // 시각화 띠 차단. + 빈 화면에 갇히는 케이스 회피 위해 portrait 재요청 —
    // 단, BracketScreen 이 top route 일 때만 (ScoreboardPage push 중에는 발동 X
    // 해야 점수판 landscape 회전을 방해 안 함).
    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      final isTopRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (isTopRoute) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
          }
        });
      }
      return const Scaffold(
          backgroundColor: Colors.white, body: SizedBox.expand());
    }
    return Scaffold(
      backgroundColor: AppColors.gray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: -4,
        leadingWidth: 34,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.maybePop(context),
          icon:
              const Icon(Icons.arrow_back_ios_new, size: 20, color: _headerInk),
        ),
        title: Text(_tournament.name,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: _headerInk,
            ),
            overflow: TextOverflow.ellipsis),
        actions: [
          // 디버그/운영용: 기존 매치 doc 의 teamA/teamB/teamANames/teamBNames/createdBy
          // 누락 필드를 현재 페어 정보로 백필. 1회 자동 실행 외 수동 재실행 통로.
          PopupMenuButton<String>(
            tooltip: '운영',
            icon: const Icon(Icons.more_vert, color: _headerInk),
            onSelected: (v) {
              if (v == 'backfill_matches') {
                _runMatchBackfillNow();
              } else if (v == 'test_crash') {
                _triggerTestCrash();
              } else if (v == 'signatures') {
                _openSignaturesPage();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'signatures',
                child: Row(children: [
                  Icon(Icons.draw_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('서명 모음'),
                ]),
              ),
              PopupMenuItem<String>(
                value: 'backfill_matches',
                child: Row(children: [
                  Icon(Icons.build_circle_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('매치 doc 백필 실행'),
                ]),
              ),
              PopupMenuItem<String>(
                value: 'test_crash',
                child: Row(children: [
                  Icon(Icons.bug_report_outlined,
                      size: 18, color: Color(0xFFB91C1C)),
                  SizedBox(width: 8),
                  Text('Crashlytics 테스트 크래시',
                      style: TextStyle(color: Color(0xFFB91C1C))),
                ]),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tc,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.blue,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(height: 44, child: Text('참가자', maxLines: 1)),
            Tab(height: 44, child: Text('설정', maxLines: 1)),
            Tab(height: 44, child: Text('대진표', maxLines: 1)),
            Tab(height: 44, child: Text('경기시간', maxLines: 1)),
            Tab(height: 44, child: Text('입상자', maxLines: 1)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tc,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _ParticipantsTab(this),
          _SettingsTab(this),
          BracketGeneratorTab(
            tournament: _tournament,
            selectedPlayers: SampleData.players
                .where((p) => _selected.contains(p.id))
                .toList(),
            assignMap: _effectiveAssignMap,
            activeAgeGroups: _activeAgeGroups,
            activeGrades: _activeGrades,
            matchScores: _matchScores,
            autoMergeAges: _autoMergeAges,
            totalDays: _totalDays,
            divisionDay: (d) {
              // 첫 매칭 일자 찾기. (event, age, grade) 모두 그 일자의 셋에 포함되어야.
              for (int day = 1; day <= _totalDays; day++) {
                final events = _dayEvents[day] ?? const <String>[];
                if (!events.contains(d.event)) continue;
                final ages = _dayEventAges[day]?[d.event];
                if (ages != null && !ages.contains(d.ageGroup)) continue;
                final grades = _dayEventGrades[day]?[d.event];
                if (grades != null && !grades.contains(d.grade)) continue;
                return day;
              }
              return 1; // 매칭 안 되면 1일차로 폴백
            },
            onChanged: (events, divisions) {
              setState(() {
                _tournament = _tournament.copyWith(
                  bracketEvent: events.join(','),
                  divisions: divisions ?? const <Division>[],
                );
              });
              _persistTournament();
            },
          ),
          _ScheduleTab(this),
          _ResultsTab(this),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 1: 참가자
// ═══════════════════════════════════════════════════════
class _ParticipantsTab extends StatelessWidget {
  final _BracketScreenState s;
  const _ParticipantsTab(this.s);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
        child: Row(children: [
          Expanded(
            child: FilterChipRow(
              options: const ['혼복', '남복', '여복'],
              selected: s._type,
              onSelect: (v) {
                s.rebuild(() => s._type = v);
                StorageService.saveBracketTypeFilter(s._tournament.id, v);
              },
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 6),
          _PillBtn(
            icon: Icons.search,
            label: '선수검색',
            onTap: () => _showPlayerSearch(context, s),
            bg: AppColors.gray2,
            fg: AppColors.text2,
          ),
        ]),
      ),
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
        child: Row(children: [
          // 참가자 추가는 manager+ 만 노출 — 익명/player 는 보안규칙에서 write 가
          // 거부되므로 UI 자체를 숨겨 카운터만 증가하다 stream emit 으로 사라지는
          // 혼란을 차단한다.
          ValueListenableBuilder<String>(
            valueListenable: AuthService.instance.currentRole,
            builder: (_, role, __) {
              if (!UserRole.isManagerOrAdmin(role)) {
                return const SizedBox.shrink();
              }
              return _PillBtn(
                icon: Icons.person_add_alt_1_rounded,
                label: '참가자 추가',
                onTap: () => _onParticipantAdd(context, s),
                bg: const Color(0xFF3730A3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                fontSize: 13,
              );
            },
          ),
          const Spacer(),
          _PillBtn(
            label: '등급별',
            onTap: () => _showGradeSummary(context, s),
            bg: AppColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            fontSize: 13,
          ),
          const SizedBox(width: 6),
          _PillBtn(
            label: '클럽별',
            onTap: () => _showClubLookup(context, s),
            bg: AppColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            fontSize: 13,
          ),
        ]),
      ),
      Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
        alignment: Alignment.centerLeft,
        child: const Text(
          '칩 길게 누르면 삭제 · [+] 로 추가',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
      ),
      _DecadeToggleBar(s),
      _GradeToggleBar(s),
      _SelectionSummary(s),
      // viewport 가 음수/0 이 되는 transitional state (점수판 portrait 복귀 직후 등)
      // 에 RenderFlex OVERFLOW 시각화 띠가 뜨는 것을 차단. height 가 충분할 때만
      // 실제 ListView 렌더, 부족하면 빈 자리.
      Expanded(
        child: LayoutBuilder(builder: (ctx, c) {
          if (c.maxHeight < 1) return const SizedBox.shrink();
          return _AgedPlayerList(s);
        }),
      ),
      Container(
        color: AppColors.gray,
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          12 + MediaQuery.of(context).padding.bottom, // 시스템 제스처 바 영역 확보
        ),
        child: Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () {
                    final ids =
                        s._filteredPlayers.map((p) => p.id).toList();
                    s.rebuild(() => s._addToSelection(ids));
                  },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                  child: const Text('전체선택', style: TextStyle(fontSize: 13)))),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton(
                  onPressed: () {
                    final ids =
                        s._filteredPlayers.map((p) => p.id).toList();
                    s.rebuild(() => s._removeFromSelection(ids));
                  },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                  child: const Text('전체해제', style: TextStyle(fontSize: 13)))),
          const SizedBox(width: 8),
          Expanded(
              flex: 2,
              child: ElevatedButton(
                  onPressed: () => s._tc.animateTo(1),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11)),
                  child:
                      const Text('설정으로 →', style: TextStyle(fontSize: 13)))),
        ]),
      ),
    ]);
  }
}

class _DecadeToggleBar extends StatelessWidget {
  final _BracketScreenState s;
  const _DecadeToggleBar(this.s);

  @override
  Widget build(BuildContext context) {
    final labels = s._ageGroupLabels;
    final allOn =
        labels.isNotEmpty && labels.every(s._activeAgeGroups.contains);
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            s.rebuild(() {
              if (allOn) {
                s._activeAgeGroups.clear();
                s._openSections.clear();
                for (final dayMap in s._dayEventAges.values) {
                  for (final set in dayMap.values) {
                    set.clear();
                  }
                }
              } else {
                s._activeAgeGroups
                  ..clear()
                  ..addAll(labels);
                s._openSections
                  ..clear()
                  ..addAll(labels);
                for (int d = 1; d <= s._totalDays; d++) {
                  for (final e in s._dayEvents[d] ?? const <String>[]) {
                    s._dayEventAgesFor(d, e)
                      ..clear()
                      ..addAll(labels);
                  }
                }
              }
            });
            s._saveChipFiltersDebounced();
            s._saveScheduleDebounced();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: allOn ? AppColors.amber : AppColors.amber2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.amber,
                width: 1.5,
              ),
            ),
            child: Text(
              '연령',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: allOn ? Colors.white : AppColors.amberText,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...labels.map((label) {
                  final on = s._activeAgeGroups.contains(label);
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: () {
                        s.rebuild(() {
                          if (on) {
                            s._activeAgeGroups.remove(label);
                            s._openSections.remove(label);
                            for (final dayMap in s._dayEventAges.values) {
                              for (final set in dayMap.values) {
                                set.remove(label);
                              }
                            }
                          } else {
                            s._activeAgeGroups.add(label);
                            s._openSections.add(label);
                            for (int d = 1; d <= s._totalDays; d++) {
                              for (final e
                                  in s._dayEvents[d] ?? const <String>[]) {
                                s._dayEventAgesFor(d, e).add(label);
                              }
                            }
                          }
                        });
                        s._saveChipFiltersDebounced();
                        s._saveScheduleDebounced();
                      },
                      onLongPress: () =>
                          _showDeleteGroupDialog(context, label, isAge: true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          color: on
                              ? AppColors.primaryMid
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: on
                                ? AppColors.primaryMid
                                : const Color(0xFFBFDBFE),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$label${on ? ' ✓' : ' +'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                on ? FontWeight.w600 : FontWeight.w500,
                            color: on
                                ? Colors.white
                                : AppColors.primaryMid,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                _AddChip(onTap: () => _showAddAgeDialog(context)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  void _showAddAgeDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('연령 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: '예: 45 또는 고등학생'),
            ),
            const SizedBox(height: 8),
            const Text(
              '숫자(20, 45 등)는 자동 나이 매칭. 텍스트는 운영자 수동 선택용.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final raw = ctrl.text.trim();
              if (raw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('라벨을 입력하세요.')));
                return;
              }
              if (s._tournament.ageGroups.contains(raw)) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이미 존재하는 그룹입니다.')));
                return;
              }
              s._addAgeGroup(raw);
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, String label,
      {required bool isAge}) {
    if (label == '전체') return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('$label 삭제'),
        content: Text(isAge
            ? '이 연령 그룹을 삭제하시겠습니까?'
            : '이 급수 그룹을 삭제하시겠습니까? 해당 급수 선수는 자동 필터에서 제외됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (isAge) {
                s._removeAgeGroup(label);
              } else {
                s._removeGradeGroup(label);
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeToggleBar extends StatelessWidget {
  final _BracketScreenState s;
  const _GradeToggleBar(this.s);

  @override
  Widget build(BuildContext context) {
    final options = s._gradeGroupLabels;
    final allOn =
        options.isNotEmpty && options.every(s._activeGrades.contains);
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(children: [
        GestureDetector(
          onTap: () {
            s.rebuild(() {
              if (allOn) {
                s._activeGrades.clear();
                for (final dayMap in s._dayEventGrades.values) {
                  for (final set in dayMap.values) {
                    set.clear();
                  }
                }
              } else {
                s._activeGrades
                  ..clear()
                  ..addAll(options);
                for (int d = 1; d <= s._totalDays; d++) {
                  for (final e in s._dayEvents[d] ?? const <String>[]) {
                    s._dayEventGradesFor(d, e)
                      ..clear()
                      ..addAll(options);
                  }
                }
              }
            });
            s._saveChipFiltersDebounced();
            s._saveScheduleDebounced();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(
              color: allOn ? AppColors.amber : AppColors.amber2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.amber,
                width: 1.5,
              ),
            ),
            child: Text(
              '전체',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: allOn ? Colors.white : AppColors.amberText,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...options.map((g) {
                  final on = s._activeGrades.contains(g);
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: GestureDetector(
                      onTap: () {
                        s.rebuild(() {
                          if (on) {
                            s._activeGrades.remove(g);
                            for (final dayMap in s._dayEventGrades.values) {
                              for (final set in dayMap.values) {
                                set.remove(g);
                              }
                            }
                          } else {
                            s._activeGrades.add(g);
                            for (int d = 1; d <= s._totalDays; d++) {
                              for (final e
                                  in s._dayEvents[d] ?? const <String>[]) {
                                s._dayEventGradesFor(d, e).add(g);
                              }
                            }
                          }
                        });
                        s._saveChipFiltersDebounced();
                        s._saveScheduleDebounced();
                      },
                      onLongPress: () =>
                          _showDeleteDialog(context, g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          color: on
                              ? AppColors.primaryMid
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: on
                                ? AppColors.primaryMid
                                : const Color(0xFFBFDBFE),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '$g${on ? ' ✓' : ' +'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                on ? FontWeight.w600 : FontWeight.w500,
                            color: on
                                ? Colors.white
                                : AppColors.primaryMid,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                _AddChip(onTap: () => _showAddDialog(context)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  void _showAddDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('급수 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: '예: 자강조'),
            ),
            const SizedBox(height: 8),
            const Text(
              '선수의 급수가 일치하면 자동 분류됩니다.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final raw = ctrl.text.trim();
              if (raw.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('라벨을 입력하세요.')));
                return;
              }
              if (s._tournament.gradeGroups.contains(raw)) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이미 존재하는 그룹입니다.')));
                return;
              }
              s._addGradeGroup(raw);
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String label) {
    if (label == '전체') return;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('$label 삭제'),
        content:
            const Text('이 급수 그룹을 삭제하시겠습니까? 해당 급수 선수는 자동 필터에서 제외됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              s._removeGradeGroup(label);
              Navigator.of(dialogCtx).pop();
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.gray3, width: 1.5),
            ),
            child: const Icon(Icons.add, size: 16, color: AppColors.muted),
          ),
        ),
      );
}

class _SelectionSummary extends StatelessWidget {
  final _BracketScreenState s;
  const _SelectionSummary(this.s);

  @override
  Widget build(BuildContext context) {
    final filtered = s._filteredPlayers;
    final selectedInFilter =
        filtered.where((p) => s._selected.contains(p.id)).length;
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(children: [
        Text('선택인원 ${filtered.length}명',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted)),
        const Spacer(),
        Text('선택 $selectedInFilter / ${s._selected.length}명',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.blue)),
      ]),
    );
  }
}

class _AgedPlayerList extends StatelessWidget {
  final _BracketScreenState s;
  const _AgedPlayerList(this.s);

  @override
  Widget build(BuildContext context) {
    final filtered = s._filteredPlayers;
    final activeLabels =
        s._ageGroupLabels.where(s._activeAgeGroups.contains).toList();

    final sections = <Widget>[];
    for (final label in activeLabels) {
      final arr =
          filtered
              .where((p) => ageMatches(label, p.age, s._ageGroupLabels))
              .toList();
      // 동일 조건(같은 연령 섹션) 내 정렬: 급수(자강조 → ... → 초심조) → 나이↑ → 이름 가나다
      arr.sort((a, b) {
        final g = a.gradeIndex.compareTo(b.gradeIndex);
        if (g != 0) return g;
        final ag = a.age.compareTo(b.age);
        if (ag != 0) return ag;
        return a.name.compareTo(b.name);
      });
      if (arr.isEmpty) continue;
      final selCnt = arr.where((p) => s._selected.contains(p.id)).length;
      final isOpen = s._openSections.contains(label);

      sections.add(_AgeSectionTile(
        label: label,
        total: arr.length,
        selected: selCnt,
        isOpen: isOpen,
        onToggle: () => s.rebuild(() {
          isOpen
              ? s._openSections.remove(label)
              : s._openSections.add(label);
        }),
        children: isOpen
            ? arr
                .take(60)
                .map((p) => ValueListenableBuilder<String>(
                      // 선수 편집/삭제는 manager+ 만 — 보안규칙에서도 어차피
                      // PERMISSION_DENIED 라 UI 차원에서 메뉴 자체를 숨겨 혼란 차단.
                      valueListenable: AuthService.instance.currentRole,
                      builder: (_, role, __) {
                        final canManage = UserRole.isManagerOrAdmin(role);
                        return PlayerSelectItem(
                          player: p,
                          isSelected: s._selected.contains(p.id),
                          onTap: () {
                            s.rebuild(() {
                              if (s._selected.contains(p.id)) {
                                s._removeFromSelection([p.id]);
                              } else {
                                s._addToSelection([p.id]);
                              }
                            });
                          },
                          onEdit: canManage
                              ? () => _editPlayer(context, p)
                              : null,
                          onDelete: canManage
                              ? () => _confirmDeletePlayer(context, p)
                              : null,
                        );
                      },
                    ))
                .toList()
            : [],
        extra: isOpen && arr.length > 60 ? arr.length - 60 : 0,
      ));
    }

    if (sections.isEmpty) {
      return const Center(
          child: Text('해당하는 참가자가 없습니다.',
              style: TextStyle(color: AppColors.muted)));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: sections,
    );
  }

  /// 선수 편집 — 이름·성별·생년월일·소속·급수·연락처 모두 [EditPlayerScreen] 폼에서.
  /// 저장은 폼 내부에서 SampleData.updatePlayer 호출, playersRev 가 갱신되어 자동 리빌드.
  Future<void> _editPlayer(BuildContext context, Player p) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPlayerScreen(
          player: p,
          initialGrades: s._gradeGroupLabels,
          onAddGrade: s._addGradeGroup,
          onRemoveGrade: s._removeGradeGroup,
        ),
      ),
    );
  }

  /// 선수 단일 삭제 확인. 확인 시 SampleData.players 에서 영구 제거 + 영속화.
  Future<void> _confirmDeletePlayer(BuildContext context, Player p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('선수 삭제'),
        content: Text(
            '"${p.name} (${p.gender}, ${p.age}세)" 선수를 명단에서 삭제하시겠습니까?\n'
            '이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제',
                  style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok == true) s._removePlayer(p.id);
  }
}

class _AgeSectionTile extends StatelessWidget {
  final String label;
  final int total, selected, extra;
  final bool isOpen;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _AgeSectionTile({
    required this.label,
    required this.total,
    required this.selected,
    required this.extra,
    required this.isOpen,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            color: const Color(0xFFF7F9FC),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Row(children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('$total명 · 선택 $selected명',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const Spacer(),
              Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: AppColors.gray3),
            ]),
          ),
        ),
        ...children,
        if (extra > 0)
          Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFFF8FAFC),
              child: Center(
                  child: Text('외 $extra명 (급수 필터 이용)',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)))),
        Container(height: 2, color: AppColors.gray2),
      ]);
}

// ═══════════════════════════════════════════════════════
//  TAB 2: 설정
// ═══════════════════════════════════════════════════════
class _SettingsTab extends StatelessWidget {
  final _BracketScreenState s;
  const _SettingsTab(this.s);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: 12 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(children: [
          _DateCard(s),
          _MatchTimeCard(s),
          ...List.generate(s._venues.length,
              (i) => _VenueEditCard(s: s, index: i)),
          // + 경기장 추가
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => s._addVenue(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('경기장 추가',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryMid,
                  side: const BorderSide(
                      color: Color(0xFFB8C9F0), width: 1.6),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          _EventGradeCard(s),
          _AssignTable(s),
          _PriorityCard(s),
          _CourtSummary(s),
          _AutoMergeAgesCard(s),
          const SizedBox(height: 12),
          _PlayerResetCard(s),
        ]),
      );
}

/// 설정 탭의 '참가자 부족 시 자동 합치기' 스위치 카드.
/// ON 이면 대진표 생성 시 (종목·급수) 안의 인접 연령을 합쳐 각 셀이 6명을 확보하도록 함.
class _AutoMergeAgesCard extends StatelessWidget {
  final _BracketScreenState s;
  const _AutoMergeAgesCard(this.s);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB8C9F0), width: 2.5),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('참가자 부족 시 자동 합치기',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              SizedBox(height: 2),
              Text(
                  '같은 종목·급수 안에서 인접 연령을 합쳐\n각 부서가 최소 6명(=3팀)을 확보',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      height: 1.35)),
            ],
          ),
        ),
        Switch(
          value: s._autoMergeAges,
          onChanged: s._toggleAutoMergeAges,
          activeThumbColor: AppColors.primaryMid,
        ),
      ]),
    );
  }
}

/// 경기 진행 순서 — 종목/연령/급수 우선순위.
/// 스케줄러(_collectRows)가 같은 경기장 안에서 어떤 급수를 먼저 진행할지,
/// 어떤 종목·연령을 우선 배치할지 결정. 대진표 생성 후에만 의미가 있어
/// divisions 가 비어 있으면 카드 자체를 노출하지 않는다.
class _PriorityCard extends StatefulWidget {
  final _BracketScreenState s;
  const _PriorityCard(this.s);

  @override
  State<_PriorityCard> createState() => _PriorityCardState();
}

class _PriorityCardState extends State<_PriorityCard> {
  /// 현재 인라인으로 펼쳐진 카테고리. 'event' | 'age' | 'grade' | null.
  String? _expandedKind;

  List<String> get _eventPriority =>
      widget.s._tournament.eventPriorityList;
  List<String> get _gradePriority =>
      widget.s._tournament.gradePriorityList;
  List<String> get _agePriority =>
      widget.s._tournament.agePriorityList;

  List<String> _priorityListOf(String kind) {
    switch (kind) {
      case 'grade':
        return _gradePriority;
      case 'age':
        return _agePriority;
      case 'event':
      default:
        return _eventPriority;
    }
  }

  /// 칩 토글: 미선택 → 우선순위 끝에 추가, 이미 선택 → 제거.
  /// 누른 순서대로 1, 2, 3 ... 순번이 매겨진다.
  void _togglePriority(String kind, String value) {
    final cur = List<String>.from(_priorityListOf(kind));
    if (cur.contains(value)) {
      cur.remove(value);
    } else {
      cur.add(value);
    }
    final joined = cur.join(',');
    final t = widget.s._tournament;
    final next = switch (kind) {
      'grade' => t.copyWith(gradePriority: joined),
      'age' => t.copyWith(agePriority: joined),
      _ => t.copyWith(eventPriority: joined),
    };
    widget.s.rebuild(() => widget.s._tournament = next);
    widget.s._persistTournament();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.s._tournament;
    if (t.divisions.isEmpty) return const SizedBox.shrink();

    final presentEvents = t.divisions.map((d) => d.event).toSet().toList()
      ..sort((a, b) => Tournament.allEventTypes
          .indexOf(a)
          .compareTo(Tournament.allEventTypes.indexOf(b)));
    final presentGrades = t.divisions.map((d) => d.grade).toSet().toList()
      ..sort();
    final presentAges = t.divisions.map((d) => d.ageGroup).toSet().toList()
      ..sort((a, b) {
        final na = int.tryParse(a) ?? 0;
        final nb = int.tryParse(b) ?? 0;
        return na.compareTo(nb);
      });

    final entries = <({
      String label,
      String kind,
      List<String> candidates,
      List<String> ranked
    })>[
      if (presentEvents.length >= 2)
        (label: '종목', kind: 'event', candidates: presentEvents, ranked: _eventPriority),
      if (presentAges.length >= 2)
        (label: '연령', kind: 'age', candidates: presentAges, ranked: _agePriority),
      if (presentGrades.length >= 2)
        (label: '급수', kind: 'grade', candidates: presentGrades, ranked: _gradePriority),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    final exp =
        entries.where((e) => e.kind == _expandedKind).cast<dynamic>().firstOrNull;

    return _card(
      title: '경기순서',
      subtitle: '같은 경기장 안에서 진행될 순서 — 카테고리 클릭 후 칩 누른 순서대로 1·2·3',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < entries.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        _categoryButton(
                          label: entries[i].label,
                          kind: entries[i].kind,
                          candidates: entries[i].candidates,
                          ranked: entries[i].ranked,
                          expanded: entries[i].kind == _expandedKind,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (exp != null) ...[
            const SizedBox(height: 8),
            _inlinePriorityEditor(
              kind: exp.kind as String,
              candidates: exp.candidates as List<String>,
              ranked: exp.ranked as List<String>,
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryButton({
    required String label,
    required String kind,
    required List<String> candidates,
    required List<String> ranked,
    required bool expanded,
  }) {
    final hasRanked = ranked.any(candidates.contains);
    return GestureDetector(
      onTap: () => setState(() {
        _expandedKind = expanded ? null : kind;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: expanded ? AppColors.primaryMid : AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: expanded
                ? AppColors.primaryMid
                : (hasRanked ? AppColors.primaryMid : AppColors.gray2),
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: expanded ? Colors.white : AppColors.text2,
                    letterSpacing: -0.2)),
            const SizedBox(width: 4),
            Icon(expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: expanded ? Colors.white : AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _inlinePriorityEditor({
    required String kind,
    required List<String> candidates,
    required List<String> ranked,
  }) {
    final inRanked = ranked.toSet();
    final tail = candidates.where((c) => !inRanked.contains(c)).toList();
    final display = [...ranked.where(candidates.contains), ...tail];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gray2, width: 1),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in display)
            _orderChip(
              label: label,
              rank: () {
                final idx = ranked.indexOf(label);
                return idx < 0 ? null : idx + 1;
              }(),
              onTap: () => _togglePriority(kind, label),
            ),
        ],
      ),
    );
  }

  Widget _orderChip({
    required String label,
    required int? rank,
    required VoidCallback onTap,
  }) {
    final ranked = rank != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: ranked ? AppColors.primaryMid : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: ranked ? AppColors.primaryMid : AppColors.gray2,
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ranked) ...[
              Text('$rank',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ranked ? Colors.white : AppColors.muted,
                    letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}

/// 선수 명단 초기화 카드 — 설정 탭 제일 하단.
/// 전체 선수 명단을 영구 삭제. 두 단계 확인.
/// (현재 대회 참가자 해제는 참가자 탭의 '전체해제' 가 담당.)
class _PlayerResetCard extends StatelessWidget {
  final _BracketScreenState s;
  const _PlayerResetCard(this.s);

  Future<void> _confirmClearAllPlayers(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('전체 선수 명단 삭제'),
        content: Text(
            '등록된 선수 ${SampleData.players.length}명을 모두 삭제합니다.\n'
            '모든 대회의 참가자 선택도 초기화됩니다.\n'
            '이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('전체 삭제',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB91C1C)))),
        ],
      ),
    );
    if (ok != true) return;
    // 한 번 더 확인 — 위험한 작업.
    final ok2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정말 모두 삭제하시겠습니까?'),
        content: const Text('마지막 확인입니다. 삭제 후 복원이 불가합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('확인',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB91C1C)))),
        ],
      ),
    );
    if (ok2 == true) s._clearAllPlayers();
  }

  @override
  Widget build(BuildContext context) => _card(
        title: '선수 명단 초기화',
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmClearAllPlayers(context),
            icon: const Icon(Icons.delete_forever_outlined, size: 16),
            label: const Text('전체 선수 명단 삭제',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB91C1C),
              side: const BorderSide(
                  color: Color(0xFFFCA5A5), width: 1.6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );
}

class _DateCard extends StatelessWidget {
  final _BracketScreenState s;
  const _DateCard(this.s);

  TextEditingController _ctrl(int day) {
    switch (day) {
      case 1:
        return s._date1Ctrl;
      case 2:
        return s._date2Ctrl;
      case 3:
        return s._date3Ctrl;
      case 4:
        return s._date4Ctrl;
      default:
        return s._date1Ctrl;
    }
  }

  Widget _dateField(int day) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: Text('$day일차',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text2)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Builder(builder: (ctx) {
              return TextField(
                  controller: _ctrl(day),
                  readOnly: true,
                  onTap: () => _pickDate(ctx, day),
                  style: const TextStyle(fontSize: 14, height: 1.0),
                  decoration: const InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      suffixIcon: Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.calendar_today, size: 13)),
                      suffixIconConstraints:
                          BoxConstraints(minWidth: 20, minHeight: 20)));
            }),
          ),
          const SizedBox(width: 6),
          _StartTimeButton(s: s, day: day),
        ],
      );

  /// 날짜 picker 열기. 현재 컨트롤러 값을 initial 로, 선택 후 'YYYY-MM-DD' 로 갱신.
  /// 컨트롤러 listener 가 _saveScheduleDebounced 호출하므로 별도 저장 코드 불필요.
  Future<void> _pickDate(BuildContext context, int day) async {
    final ctrl = _ctrl(day);
    DateTime initial = DateTime.now();
    try {
      final parts = ctrl.text.trim().split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        initial = DateTime(y, m, d);
      }
    } catch (_) {/* invalid → today */}
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099, 12, 31),
    );
    if (picked == null) return;
    final yy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    ctrl.text = '$yy-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) => _card(
        title: '대회날짜',
        subtitle: '최대 ${_BracketScreenState._maxDays}일',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 대회 일수 셀렉터 — 카드 최상단에 노출.
          Row(children: [
            for (int d = 1; d <= _BracketScreenState._maxDays; d++) ...[
              if (d > 1) const SizedBox(width: 6),
              _dayBtn('$d일', s._totalDays == d, () {
                s.rebuild(() {
                  s._totalDays = d;
                  s._selectedScheduleDay =
                      s._selectedScheduleDay.clamp(1, d);
                });
                s._recomputeUnionEventType();
                s._saveScheduleDebounced();
              }),
            ],
          ]),
          const SizedBox(height: 6),
          _dateField(1),
          _dayVenueRow(1),
          for (int d = 2; d <= s._totalDays; d++) ...[
            const SizedBox(height: 4),
            _dateField(d),
            _dayVenueRow(d),
          ],
        ]),
      );

  /// 그 일자에 사용할 경기장 토글 행 — 정의된 경기장이 2개 이상일 때만 노출.
  /// 칩 탭으로 ON/OFF. 활성 경기장은 venue 색으로, 비활성은 회색으로 표시.
  /// 최소 1개는 ON 으로 남아야 함 (가드).
  Widget _dayVenueRow(int day) {
    if (s._venues.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(46, 4, 0, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          const Text('사용 경기장',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted)),
          const SizedBox(width: 6),
          for (int i = 0; i < s._venues.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Builder(builder: (_) {
              final v = s._venues[i];
              final on = s._isVenueActiveOnDay(day, v.id);
              final label = v.name.isEmpty ? '경기장 ${i + 1}' : v.name;
              final hex = v.colorHex.replaceAll('#', '');
              Color color;
              try {
                color = Color(int.parse('FF$hex', radix: 16));
              } catch (_) {
                color = AppColors.blue;
              }
              return GestureDetector(
                onTap: () => s._toggleVenueOnDay(day, v.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: on ? color : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: on ? color : AppColors.gray3, width: 1.3),
                  ),
                  child: Text(
                    on ? '$label ✓' : label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: on ? Colors.white : AppColors.muted),
                  ),
                ),
              );
            }),
          ],
        ]),
      ),
    );
  }

  Widget _dayBtn(String lbl, bool on, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
                color: on ? AppColors.blue2 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: on ? AppColors.blue2 : AppColors.gray3,
                    width: 1.5)),
            child: Center(
                child: Text(lbl,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : AppColors.text2))),
          ),
        ),
      );
}

/// 일자별 경기 시작 시간 칩 — 탭하면 TimePicker 열림.
/// 데이터는 [_BracketScreenState._tournament.daySchedule] 와 공유되므로 경기시간 카드와
/// 자동 동기화 (한 곳에서 바꿔도 다른 곳에 반영).
class _StartTimeButton extends StatelessWidget {
  final _BracketScreenState s;
  final int day;
  const _StartTimeButton({required this.s, required this.day});

  Future<void> _pick(BuildContext context) async {
    final cur = s._tournament.daySchedule(day).startTime;
    final parts = cur.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    s._updateDaySchedule(day, startTime: '$hh:$mm');
  }

  @override
  Widget build(BuildContext context) {
    final time = s._tournament.daySchedule(day).startTime;
    const skyBlue = Color(0xFF0996F2);
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: skyBlue,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: skyBlue, width: 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.access_time, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(time,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      ),
    );
  }
}

/// 공용 ⊖/⊕ 동그라미 버튼
/// 작은 색 칩 — 탭하면 onPick 콜백.
class _VenueColorChip extends StatelessWidget {
  final String colorHex;
  final VoidCallback onPick;
  const _VenueColorChip({required this.colorHex, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final clean = colorHex.replaceAll('#', '');
    Color color;
    try {
      color = Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      color = AppColors.blue;
    }
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.4),
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  const _CounterButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? AppColors.primaryMid : AppColors.gray,
          ),
          child: Icon(
            icon,
            size: 13,
            color: enabled ? Colors.white : AppColors.gray3,
          ),
        ),
      );
}

/// 운영자가 첫 경기 시각/경기당 소요 시간을 입력하는 카드.
/// 입력은 디바운스 저장되어 대진표 일정 자동 계산에 반영된다.
class _MatchTimeCard extends StatefulWidget {
  final _BracketScreenState s;
  const _MatchTimeCard(this.s);

  @override
  State<_MatchTimeCard> createState() => _MatchTimeCardState();
}

class _MatchTimeCardState extends State<_MatchTimeCard> {
  late TextEditingController _durationCtrl;
  final List<TextEditingController> _startCtrls = [];
  final List<TextEditingController> _breakStartCtrls = [];
  final List<TextEditingController> _breakDurationCtrls = [];
  final List<bool> _breakOn = [];

  @override
  void initState() {
    super.initState();
    final t = widget.s._tournament;
    _durationCtrl =
        TextEditingController(text: t.matchDurationMinutes.toString());
    _syncDayCtrls();
  }

  /// _totalDays 기준으로 일자별 컨트롤러를 늘리거나 줄인다.
  /// 신규 컨트롤러는 현재 _tournament.daySchedule(d) 값으로 초기화.
  void _syncDayCtrls() {
    final s = widget.s;
    final t = s._tournament;
    final days = s._totalDays;
    while (_startCtrls.length < days) {
      final d = _startCtrls.length + 1;
      final sch = t.daySchedule(d);
      _startCtrls.add(TextEditingController(text: sch.startTime));
      _breakStartCtrls.add(TextEditingController(
          text: sch.breakEnabled ? sch.breakStartTime : ''));
      _breakDurationCtrls.add(TextEditingController(
        text: sch.breakEnabled && sch.breakDurationMinutes > 0
            ? sch.breakDurationMinutes.toString()
            : '',
      ));
      _breakOn.add(sch.breakEnabled);
    }
    while (_startCtrls.length > days) {
      _startCtrls.removeLast().dispose();
      _breakStartCtrls.removeLast().dispose();
      _breakDurationCtrls.removeLast().dispose();
      _breakOn.removeLast();
    }
  }

  @override
  void didUpdateWidget(covariant _MatchTimeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDayCtrls();
    final t = widget.s._tournament;
    // _breakOn 은 UI 로컬 상태(사용자 토글 의도). 데이터에서 다시 끌어오지 않는다.
    // 1일차의 breakEnabled 는 legacy 필드(start/duration 비어 있음)에서 파생되므로
    // 토글만 켠 직후엔 false 로 보일 수 있어, 이를 그대로 _breakOn 에 미러링하면
    // 토글이 즉시 다시 꺼져버린다(버그). UI 상태는 _toggleBreak 에서만 갱신.
    for (int i = 0; i < _startCtrls.length; i++) {
      final sch = t.daySchedule(i + 1);
      if (_startCtrls[i].text != sch.startTime) {
        _startCtrls[i].text = sch.startTime;
      }
      // 휴식 필드 값은 _breakOn(UI 의도) 기준. 토글 OFF 면 보이지 않으므로 클리어 OK.
      final wantBStart = _breakOn[i] ? sch.breakStartTime : '';
      if (_breakStartCtrls[i].text != wantBStart) {
        _breakStartCtrls[i].text = wantBStart;
      }
      final wantBDur = _breakOn[i] && sch.breakDurationMinutes > 0
          ? sch.breakDurationMinutes.toString()
          : '';
      if (_breakDurationCtrls[i].text != wantBDur) {
        _breakDurationCtrls[i].text = wantBDur;
      }
    }
    final dur = t.matchDurationMinutes.toString();
    if (_durationCtrl.text != dur) _durationCtrl.text = dur;
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    for (final c in _startCtrls) c.dispose();
    for (final c in _breakStartCtrls) c.dispose();
    for (final c in _breakDurationCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime(int day) async {
    final cur = widget.s._tournament.daySchedule(day).startTime;
    final parts = cur.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final s = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    _startCtrls[day - 1].text = s;
    widget.s._updateDaySchedule(day, startTime: s);
  }

  Future<void> _pickBreakStart(int day) async {
    final cur = widget.s._tournament.daySchedule(day).breakStartTime;
    final parts = cur.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 11,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final s = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    _breakStartCtrls[day - 1].text = s;
    widget.s._updateDaySchedule(day,
        breakEnabled: true, breakStartTime: s);
  }

  void _toggleBreak(int day, bool on) {
    setState(() => _breakOn[day - 1] = on);
    if (!on) {
      _breakStartCtrls[day - 1].text = '';
      _breakDurationCtrls[day - 1].text = '';
      widget.s._updateDaySchedule(day,
          breakEnabled: false,
          breakStartTime: '',
          breakDurationMinutes: 0);
    } else {
      widget.s._updateDaySchedule(day, breakEnabled: true);
    }
  }

  Widget _dayBlock(int day) {
    final breakOn = _breakOn[day - 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // [N일차 중간 휴식시간 (개회식 등)] + ON/OFF 토글
        SizedBox(
          height: 28,
          child: Row(children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '$day일차 중간 휴식시간',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text2)),
                  const TextSpan(
                    text: '  (개회식 등)',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: breakOn,
                onChanged: (v) => _toggleBreak(day, v),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),
        if (breakOn) ...[
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _breakStartCtrls[day - 1],
                readOnly: true,
                onTap: () => _pickBreakStart(day),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, height: 1.0),
                decoration: const InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  hintText: '시작 (예: 10:30)',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  suffixIcon: Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.schedule, size: 13),
                  ),
                  suffixIconConstraints:
                      BoxConstraints(minWidth: 20, minHeight: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _breakDurationCtrls[day - 1],
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, height: 1.0),
                decoration: const InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  hintText: '길이 (예: 60) 분',
                  suffixText: '분',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null && n >= 0) {
                    widget.s._updateDaySchedule(day,
                        breakEnabled: true, breakDurationMinutes: n);
                  }
                },
              ),
            ),
          ]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.s._totalDays;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB8C9F0), width: 2.5),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 + 경기당 입력을 한 줄에 배치.
          Row(children: [
            const Text('경기시간',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text2)),
            const Spacer(),
            const Text('경기당',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text2)),
            const SizedBox(width: 6),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _durationCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500, height: 1.0),
                decoration: const InputDecoration(
                  isDense: true,
                  isCollapsed: true,
                  hintText: '30',
                  suffixText: '분',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  if (n != null && n >= 0) {
                    widget.s._updateMatchTiming(durationMinutes: n);
                  }
                },
              ),
            ),
          ]),
          const Divider(height: 8, color: AppColors.divider),
          for (int d = 1; d <= days; d++) ...[
            if (d > 1)
              const Divider(height: 6, color: AppColors.divider),
            _dayBlock(d),
          ],
        ],
      ),
    );
  }
}

/// 경기정보 카드 — 종별/연령/급수 선택 (참가자 탭 토글 상태와 동기화).
/// 추가/삭제는 참가자 탭에서 (이 카드는 선택만).
class _EventGradeCard extends StatelessWidget {
  final _BracketScreenState s;
  const _EventGradeCard(this.s);

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color? selBg,
    Color? selFg,
  }) {
    final bg = selected ? (selBg ?? AppColors.primaryMid) : AppColors.gray;
    final fg = selected ? (selFg ?? Colors.white) : AppColors.text2;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? (selBg ?? AppColors.primaryMid)
                : const Color(0xFFD8DEE8),
            width: 1.4,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selDay = s._selectedScheduleDay.clamp(1, s._totalDays);
    final selectedEvents =
        (s._dayEvents[selDay] ?? const <String>[]).toSet();
    final ageLabels = s._ageGroupLabels;
    final gradeLabels = s._gradeGroupLabels;

    return _card(
      title: '경기정보',
      subtitle: '일자·종별별 연령/급수 선택',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 일자 탭 — 대회 일수가 2일 이상일 때만 노출.
        if (s._totalDays > 1) ...[
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (int d = 1; d <= s._totalDays; d++)
                _chip(
                  label: '$d일차',
                  selected: d == selDay,
                  onTap: () =>
                      s.rebuild(() => s._selectedScheduleDay = d),
                  selBg: const Color(0xFF3730A3),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        const Text('종별',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.text2)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: Tournament.allEventTypes
              .map((e) => _chip(
                    label: e,
                    selected: selectedEvents.contains(e),
                    onTap: () => s._toggleEvent(e),
                  ))
              .toList(),
        ),
        if (ageLabels.isEmpty || gradeLabels.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('* 참가자 탭에서 연령/급수 그룹을 추가하세요',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ),
        // 선택된 종별마다 연령/급수 칩 행을 따로 노출 → (일자·종별)별 비대칭 분할.
        for (final e in Tournament.allEventTypes)
          if (selectedEvents.contains(e))
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFE4E8F0), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryMid)),
                  if (ageLabels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 32,
                            child: Text('연령',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted)),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: ageLabels.map((l) {
                                final on = s
                                    ._dayEventAgesFor(selDay, e)
                                    .contains(l);
                                return _chip(
                                  label: l,
                                  selected: on,
                                  onTap: () => s._toggleDayEventAge(
                                      selDay, e, l),
                                );
                              }).toList(),
                            ),
                          ),
                        ]),
                  ],
                  if (gradeLabels.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 32,
                            child: Text('급수',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted)),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: gradeLabels.map((g) {
                                final on = s
                                    ._dayEventGradesFor(selDay, e)
                                    .contains(g);
                                return _chip(
                                  label: g,
                                  selected: on,
                                  onTap: () => s._toggleDayEventGrade(
                                      selDay, e, g),
                                );
                              }).toList(),
                            ),
                          ),
                        ]),
                  ],
                ],
              ),
            ),
      ]),
    );
  }
}

/// 경기장별 입력 카드 (이름/위치/코트 수)
class _VenueEditCard extends StatefulWidget {
  final _BracketScreenState s;
  final int index;
  const _VenueEditCard({required this.s, required this.index});

  @override
  State<_VenueEditCard> createState() => _VenueEditCardState();
}

class _VenueEditCardState extends State<_VenueEditCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addrCtrl;

  @override
  void initState() {
    super.initState();
    final v = widget.s._venues[widget.index];
    _nameCtrl = TextEditingController(text: v.name);
    _addrCtrl = TextEditingController(text: v.address);
  }

  @override
  void didUpdateWidget(covariant _VenueEditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final v = widget.s._venues[widget.index];
    if (_nameCtrl.text != v.name) _nameCtrl.text = v.name;
    if (_addrCtrl.text != v.address) _addrCtrl.text = v.address;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  /// 색 팔레트 다이얼로그. `Venue.defaultColors` 6색을 칩으로 보여주고 선택 시 갱신.
  Future<void> _pickVenueColor(BuildContext ctx, String current) async {
    final picked = await showDialog<String>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        title: const Text('경기장 색상'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final hex in Venue.defaultColors)
              GestureDetector(
                onTap: () => Navigator.pop(dctx, hex),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _hexToColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hex.toLowerCase() == current.toLowerCase()
                          ? AppColors.text
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('취소')),
        ],
      ),
    );
    if (picked != null) widget.s._updateVenueColor(widget.index, picked);
  }

  static Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.s._venues[widget.index];
    final disabled = v.courts == 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      decoration: BoxDecoration(
        color: disabled ? AppColors.gray : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        // 파스텔 블루 보더 — 다른 카드와 톤 통일
        border: Border.all(color: const Color(0xFFB8C9F0), width: 2.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('경기장 ${widget.index + 1}',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text2)),
          if (disabled) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.red3.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('사용 안 함',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.red)),
            ),
          ],
          const SizedBox(width: 8),
          // 색상 picker — 탭하면 팔레트 다이얼로그.
          _VenueColorChip(
            colorHex: v.colorHex,
            onPick: () => _pickVenueColor(context, v.colorHex),
          ),
          const Spacer(),
          // 경기장이 2개 이상일 때만 삭제 가능 (최소 1개 유지)
          if (widget.s._venues.length > 1)
            IconButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('경기장 삭제'),
                    content: Text(
                        '"${widget.s._venues[widget.index].name.isEmpty ? '경기장 ${widget.index + 1}' : widget.s._venues[widget.index].name}" 을(를) 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('취소')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('삭제',
                              style:
                                  TextStyle(color: AppColors.red))),
                    ],
                  ),
                );
                if (ok == true) widget.s._removeVenue(widget.index);
              },
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.red,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: '경기장 삭제',
            ),
        ]),
        const SizedBox(height: 4),
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, height: 1.0),
          decoration: const InputDecoration(
            labelText: '대회장소',
            hintText: '예: 한국시민체육관',
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          ),
          onChanged: (val) => widget.s._updateVenueName(widget.index, val),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _addrCtrl,
          style: const TextStyle(fontSize: 14, height: 1.0),
          decoration: const InputDecoration(
            labelText: '위치',
            hintText: '예: 한국 한국시 중앙로 123',
            prefixIcon: Padding(
                padding: EdgeInsets.only(left: 6, right: 4),
                child: Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.gray3)),
            prefixIconConstraints:
                BoxConstraints(minWidth: 20, minHeight: 20),
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          ),
          maxLines: 1,
          onChanged: (val) =>
              widget.s._updateVenueAddress(widget.index, val),
        ),
        const SizedBox(height: 4),
        Row(children: [
          const Text('코트 수',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2)),
          const Spacer(),
          _CounterButton(
            icon: Icons.remove,
            enabled: v.courts > 0,
            onTap: v.courts > 0
                ? () => widget.s._updateVenueCourts(widget.index, v.courts - 1)
                : null,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '${v.courts}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CounterButton(
            icon: Icons.add,
            enabled: v.courts < _BracketScreenState._maxCourtsPerVenue,
            onTap: v.courts < _BracketScreenState._maxCourtsPerVenue
                ? () => widget.s._updateVenueCourts(widget.index, v.courts + 1)
                : null,
          ),
        ]),
      ]),
    );
  }
}

class _AssignTable extends StatefulWidget {
  final _BracketScreenState s;
  const _AssignTable(this.s);

  @override
  State<_AssignTable> createState() => _AssignTableState();
}

class _AssignTableState extends State<_AssignTable> {
  /// 현재 보고 있는 종별 (탭). 대회의 활성 종별 중 첫 번째로 시작.
  String? _activeEvent;

  // 표 구조: 구분 컬럼 폭/행 높이 상수 — 좌측 고정 + 우측 스크롤 정렬용.
  static const double _kLeftColWidth = 32;
  static const double _kVenueColWidth = 150;
  static const double _kHeaderHeight = 40;
  static const double _kRowHeight = 64;

  /// 카드 타이틀 + 안내 메시지를 보여주는 placeholder.
  /// 데이터가 아직 부족할 때(_dayEvents/_activeAges/_activeGrades 비어 있음) 표시.
  Widget _placeholder(String message) => Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB8C9F0), width: 2.5),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('연령별 급수별 경기장 배정',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const SizedBox(height: 8),
              Text(message,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                      height: 1.4)),
            ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    // 경기정보 카드와 동일한 일자 선택 사용 (_selectedScheduleDay).
    final selDay = s._selectedScheduleDay.clamp(1, s._totalDays);

    if (s._venues.isEmpty) {
      return _placeholder('* 경기장을 먼저 추가하세요.');
    }
    // 컬럼: 그 일자에 사용 가능한 경기장만 (대회날짜 카드의 일자별 사용 경기장 토글 반영).
    final venues = s._venuesActiveOnDay(selDay);
    if (venues.isEmpty) {
      return _placeholder(
          '* $selDay일차에 사용할 경기장이 없습니다. 대회날짜에서 경기장을 선택하세요.');
    }

    // 해당 일자의 종별 (경기정보 카드에서 선택).
    final events = (s._dayEvents[selDay] ?? const <String>[])
        .where(Tournament.allEventTypes.contains)
        .toList();
    if (events.isEmpty) {
      return _placeholder('* 경기정보에서 종별을 먼저 선택하세요.');
    }

    // _activeEvent 가 비활성/없는 이벤트면 첫 번째로 폴백.
    final currentEvent =
        events.contains(_activeEvent) ? _activeEvent! : events.first;

    // 현재 (일자, 종별) 의 연령/급수만 표시.
    final activeAges = s._ageGroupLabels
        .where(s._dayEventAgesFor(selDay, currentEvent).contains)
        .toList();
    final activeGrades = s._gradeGroupLabels
        .where(s._dayEventGradesFor(selDay, currentEvent).contains)
        .toList();
    if (activeAges.isEmpty || activeGrades.isEmpty) {
      return _placeholder(
          '* 경기정보에서 $currentEvent 의 연령·급수를 먼저 선택하세요.');
    }

    final totalHeight =
        _kHeaderHeight + activeAges.length * _kRowHeight;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB8C9F0), width: 2.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 제목 + AI 자동배정/자동취소 토글
        Row(children: [
          const Text('연령별 급수별 경기장 배정',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text)),
          const Spacer(),
          _aiToggleButton(s),
        ]),
        // 일자 chip — 대회 일수 2일 이상일 때만, 경기정보 카드와 동기화.
        if (s._totalDays > 1) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (int d = 1; d <= s._totalDays; d++)
                GestureDetector(
                  onTap: () =>
                      s.rebuild(() => s._selectedScheduleDay = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: d == selDay
                          ? const Color(0xFF3730A3)
                          : AppColors.gray,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: d == selDay
                              ? const Color(0xFF3730A3)
                              : const Color(0xFFD8DEE8),
                          width: 1.4),
                    ),
                    child: Text('$d일차',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: d == selDay
                                ? Colors.white
                                : AppColors.text2)),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        // 종별 선택 버튼 + 배정초기화
        Row(children: [
          for (final ev in events) ...[
            _eventTab(ev, ev == currentEvent, () {
              setState(() => _activeEvent = ev);
            }),
            if (ev != events.last) const SizedBox(width: 6),
          ],
          const Spacer(),
          _resetButton(s),
        ]),
        const SizedBox(height: 8),
        // 좌측 '구분' 컬럼 고정 + 우측 경기장 컬럼 가로 스크롤.
        SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 우측 (스크롤) — 좌측 폭만큼 padding 으로 비워두어 좌측 고정 컬럼이 위에 덮어씀.
              Padding(
                padding: const EdgeInsets.only(left: _kLeftColWidth),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // 헤더
                    Row(children: [
                      for (final v in venues)
                        _venueHeaderCell(v.name.isEmpty
                            ? '경기장 ${venues.indexOf(v) + 1}'
                            : v.name),
                    ]),
                    // 데이터 행
                    for (final age in activeAges)
                      Row(children: [
                        for (final v in venues)
                          _gradeCell(
                              currentEvent, age, v.id, activeGrades),
                      ]),
                  ]),
                ),
              ),
              // 좌측 고정 (구분 컬럼) — 흰색 배경으로 우측 콘텐츠 가림.
              SizedBox(
                width: _kLeftColWidth,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _fixedHeaderCell('구분'),
                  for (final age in activeAges) _fixedAgeCell(age),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  /// 좌측 고정 헤더 셀 (구분).
  Widget _fixedHeaderCell(String label) => Container(
        height: _kHeaderHeight,
        width: _kLeftColWidth,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.text2)),
      );

  /// 좌측 고정 연령 셀.
  Widget _fixedAgeCell(String age) => Container(
        height: _kRowHeight,
        width: _kLeftColWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(age,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.text2)),
      );

  /// AI 자동배정 / 자동취소 토글 버튼.
  /// 스냅샷이 *현재 일자* 에 대한 것일 때만 '자동취소' 모드.
  /// 다른 일자에 대한 스냅샷이면 '자동배정' 모드로 표시.
  Widget _aiToggleButton(_BracketScreenState s) {
    final selDay = s._selectedScheduleDay.clamp(1, s._totalDays);
    final hasSnapshot =
        s._preAiAssignMap != null && s._preAiAssignMap!.day == selDay;
    final bg = hasSnapshot ? AppColors.red2 : AppColors.green2;
    final label = hasSnapshot ? 'AI 자동취소' : 'AI 자동배정';
    final icon = hasSnapshot ? Icons.undo : Icons.auto_awesome;

    return GestureDetector(
      onTap: () async {
        if (hasSnapshot) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('AI 자동취소'),
              content: const Text(
                  'AI 자동배정 직전 상태로 되돌립니다.\n진행하시겠습니까?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('되돌리기',
                        style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w800))),
              ],
            ),
          );
          if (ok == true) s._undoAiAssign();
        } else {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('AI 자동 배정'),
              content: const Text(
                  '선택된 참가자 인원수에 맞춰 모든 종별·연령·급수를 경기장 코트 비율로 자동 배정합니다.\n기존 수동 배정은 모두 덮어씌워집니다.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('자동 배정',
                        style: TextStyle(fontWeight: FontWeight.w800))),
              ],
            ),
          );
          if (ok == true) s._aiAssignVenues();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ]),
      ),
    );
  }

  /// 배정초기화 버튼 — 모든 셀을 첫 경기장으로 되돌림.
  Widget _resetButton(_BracketScreenState s) => GestureDetector(
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('배정 초기화'),
              content: const Text(
                  '모든 종별·연령·급수의 경기장 배정을 첫 경기장으로 되돌립니다.\n진행하시겠습니까?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('초기화',
                        style: TextStyle(
                            color: AppColors.red,
                            fontWeight: FontWeight.w800))),
              ],
            ),
          );
          if (ok == true) s._resetAssignMap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.gray2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.refresh, size: 14, color: AppColors.text),
            SizedBox(width: 4),
            Text('배정초기화',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
          ]),
        ),
      );

  /// 우측 스크롤 헤더 셀 (경기장 이름).
  Widget _venueHeaderCell(String name) => Container(
        height: _kHeaderHeight,
        width: _kVenueColWidth,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.text2)),
      );

  /// 한 (연령, 경기장) 셀: 활성 급수 칩 나열.
  /// 칩 탭 = 해당 (event, age, grade) → venueId 로 재배정.
  Widget _gradeCell(
      String event, String age, String venueId, List<String> grades) {
    final s = widget.s;
    return Container(
      height: _kRowHeight,
      width: _kVenueColWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        alignment: WrapAlignment.center,
        children: grades.map((g) {
          final key = AssignKey(event, age, g);
          final shortG = g.replaceAll('조', '');
          // 일자별 배정 우선 — 없으면 전 일자 공통 _assignMap 으로 폴백.
          final day = s._selectedScheduleDay.clamp(1, s._totalDays);
          final dayVal = s._dayAssignMap[day]?[key];
          final globalVal = s._assignMap[key];
          final assigned =
              (dayVal ?? globalVal ?? s._venues.first.id) == venueId;
          return GestureDetector(
            onTap: () {
              s.rebuild(() {
                final dayMap = s._dayAssignMap
                    .putIfAbsent(day, () => <AssignKey, String>{});
                dayMap[key] = venueId;
              });
              s._saveDayAssign();
              s._persistTournamentDebounced();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: assigned ? AppColors.primaryMid : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: assigned
                      ? AppColors.primaryMid
                      : const Color(0xFFA8B5C7),
                  width: 1.2,
                ),
              ),
              child: Text(shortG,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: assigned ? Colors.white : AppColors.text2)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _eventTab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMid : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: selected ? AppColors.primaryMid : const Color(0xFFD8DEE8),
              width: 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.text2)),
      ),
    );
  }

  Widget _th(String t) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(t,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.text2)));
}

class _CourtSummary extends StatelessWidget {
  final _BracketScreenState s;
  const _CourtSummary(this.s);

  @override
  Widget build(BuildContext context) => _card(
        title: '코트요약',
        child: Column(children: [
          ...s._venues.map((v) {
            Color col;
            final hex = v.colorHex.replaceAll('#', '');
            try {
              col = Color(int.parse('FF$hex', radix: 16));
            } catch (_) {
              col = AppColors.blue;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: col, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(v.name,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.text2))),
                Text('${v.courts}코트',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ]),
            );
          }),
          const Divider(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('합계',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
            Text('${s._venues.fold(0, (sum, v) => sum + v.courts)}코트',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blue)),
          ]),
        ]),
      );
}

// ═══════════════════════════════════════════════════════
//  TAB 4: 경기시간 — 경기장/코트별 일정 통합 뷰
// ═══════════════════════════════════════════════════════

/// 일정 행 한 줄을 표현하는 데이터.
class _ScheduleRow {
  final String time; // "HH:mm"
  final int globalCourt;
  final int localCourt;
  final String venueId;
  final Division division;
  final String groupName; // "A조" / "본선" 등
  final int matchNum;
  final TeamData team1;
  final TeamData team2;

  /// 이 행이 속한 일자(1-base). 다일 대회에서 화면 필터에 사용.
  final int dayIdx;

  const _ScheduleRow({
    required this.time,
    required this.globalCourt,
    required this.localCourt,
    required this.venueId,
    required this.division,
    required this.groupName,
    required this.matchNum,
    required this.team1,
    required this.team2,
    this.dayIdx = 1,
  });
}

/// 글로벌 슬롯 스케줄러의 미배정 매치. division.teams 인덱스로 팀 참조.
class _PendingMatch {
  final Division division;
  final String divVenueId;
  final GroupInfo group;
  final int roundIdx;
  final int team1Index;
  final int team2Index;
  final int matchNum;

  const _PendingMatch({
    required this.division,
    required this.divVenueId,
    required this.group,
    required this.roundIdx,
    required this.team1Index,
    required this.team2Index,
    required this.matchNum,
  });
}

class _ScheduleTab extends StatefulWidget {
  final _BracketScreenState s;
  const _ScheduleTab(this.s);

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  String? _venueId;
  int? _localCourt; // 선택된 경기장의 1-base 로컬 코트 번호. null = 전체.

  /// 경기시간 탭에서 보여줄 일자(1-base). 다일 대회에서 일자별 필터링.
  int _dayFilter = 1;

  List<Venue> get _activeVenues =>
      widget.s._venues.where((v) => v.courts > 0).toList();

  @override
  void initState() {
    super.initState();
    final venues = _activeVenues;
    if (venues.isNotEmpty) {
      _venueId = venues.first.id;
    }
  }

  /// 현재 대회의 종목/급수/연령 진행 우선순위. 사용자가 설정 탭의 '경기순서' 카드에서 조정.
  /// _collectRows() 의 정렬·활성 급수 게이트에 사용.
  List<String> get _eventPriority => widget.s._tournament.eventPriorityList;
  List<String> get _gradePriority => widget.s._tournament.gradePriorityList;
  List<String> get _agePriority => widget.s._tournament.agePriorityList;

  /// 경기장의 글로벌 시작 코트 번호. 예) 1번 경기장 4코트 → 1, 2번 경기장 3코트 → 5.
  int _startCourtForVenue(String id) {
    int s = 1;
    for (final v in widget.s._venues) {
      if (v.id == id) return s;
      s += v.courts;
    }
    return 1;
  }

  /// 해당 Division 의 실제 배정 venueId.
  /// 우선순위: 1) _dayAssignMap[day][key]  2) _assignMap[key] (전 일자 공통 fallback)
  /// 3) division.venueId 4) null. day 는 dayOf(d) 결과.
  String? _resolveVenueIdForDay(Division d, int day) {
    final key = AssignKey(d.event, d.ageGroup, d.grade);
    final dayVal = widget.s._dayAssignMap[day]?[key];
    if (dayVal != null && dayVal.isNotEmpty) return dayVal;
    final live = widget.s._assignMap[key];
    if (live != null && live.isNotEmpty) return live;
    if (d.venueId.isNotEmpty) return d.venueId;
    return null;
  }

  /// 모든 Division 의 예선 경기를 한 리스트로 평탄화.
  ///
  /// 스케줄링 정책 (글로벌 슬롯 단위):
  /// - 시각 t 를 matchMin 간격으로 진행하며 매 시점 비어 있는 코트에 가능한 매치를 채움.
  /// - 매치 후보 우선순위는 (급수 → 종목 → 연령 → 그룹 → 라운드 → 페어) 순.
  ///   같은 급수가 우선 배치되지만, 그 급수의 선수들이 휴식(직전 경기 + matchMin) 중이면
  ///   greedy 하게 다음 가능한 매치로 넘어가 코트 idle 을 최소화 (지그재그 효과).
  /// - 선수별 free 시각 추적 → 같은 사람이 직전 슬롯 바로 다음 슬롯에 다시 경기하지 않음
  ///   (matchMin 만큼 강제 휴식).
  /// - 중간 휴식 구간(breakStart..breakEnd)은 시각 자체를 통째로 건너뜀.
  List<_ScheduleRow> _collectRows() {
    final s = widget.s;
    final t = s._tournament;
    final matchMin =
        t.matchDurationMinutes > 0 ? t.matchDurationMinutes : 30;
    final restMin = matchMin; // 한 슬롯 강제 휴식
    final totalDays = s._totalDays;

    int parseHm(String s, {int defaultH = 9}) {
      final parts = s.split(':');
      final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? defaultH;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
      return h * 60 + m;
    }
    String fmtTime(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

    // 종목/급수/연령 우선순위 (전 일자 공통)
    final eventPrio = _eventPriority;
    final gradePrio = _gradePriority;
    final agePrio = _agePriority;
    int idxOf(List<String> list, String v) {
      final i = list.indexOf(v);
      return i < 0 ? 99 : i;
    }

    // 해당 division 이 어느 일자에 속하는지 판단. 1..totalDays 중 첫 일치.
    // (일자, 종별) 별 ages/grades 가 lazy 초기화 전이면 전역 active* 로 폴백 — 마이그레이션 안전.
    int dayOf(Division d) {
      for (int day = 1; day <= totalDays; day++) {
        final events = s._dayEvents[day] ?? const <String>[];
        if (!events.contains(d.event)) continue;
        final agesRaw = s._dayEventAges[day]?[d.event];
        final ages = (agesRaw == null || agesRaw.isEmpty)
            ? s._activeAgeGroups
            : agesRaw;
        final gradesRaw = s._dayEventGrades[day]?[d.event];
        final grades = (gradesRaw == null || gradesRaw.isEmpty)
            ? s._activeGrades
            : gradesRaw;
        if (ages.contains(d.ageGroup) && grades.contains(d.grade)) {
          return day;
        }
      }
      return 1; // 어디에도 속하지 않으면 1일차로 폴백
    }

    // 일자별 division 분류
    final divsByDay = <int, List<Division>>{};
    for (final d in t.divisions) {
      final day = dayOf(d);
      divsByDay.putIfAbsent(day, () => []).add(d);
    }

    final allRows = <_ScheduleRow>[];

    for (int day = 1; day <= totalDays; day++) {
      final divs = divsByDay[day] ?? const <Division>[];
      if (divs.isEmpty) continue;

      final sch = t.daySchedule(day);
      final baseMin = parseHm(sch.startTime);
      int breakStart = 0;
      int breakEnd = 0;
      if (sch.breakEnabled &&
          sch.breakStartTime.isNotEmpty &&
          sch.breakDurationMinutes > 0) {
        breakStart = parseHm(sch.breakStartTime, defaultH: 11);
        breakEnd = breakStart + sch.breakDurationMinutes;
      }

      final sortedDivisions = List<Division>.from(divs);
      sortedDivisions.sort((a, b) {
        final ea = idxOf(eventPrio, a.event);
        final eb = idxOf(eventPrio, b.event);
        if (ea != eb) return ea.compareTo(eb);
        final ga = idxOf(gradePrio, a.grade);
        final gb = idxOf(gradePrio, b.grade);
        if (ga != gb) return ga.compareTo(gb);
        final aa = idxOf(agePrio, a.ageGroup);
        final ab = idxOf(agePrio, b.ageGroup);
        return aa.compareTo(ab);
      });

      // matchNum 은 (venue, day) 별 연속 카운터.
      final matchNumByVenue = <String, int>{};
      final pending = <_PendingMatch>[];
      for (final d in sortedDivisions) {
        final divVenueId = _resolveVenueIdForDay(d, day);
        if (divVenueId == null) continue;
        int teamOffset = 0;
        for (final g in d.format.groups) {
          if (g.size < 2) {
            teamOffset += g.size;
            continue;
          }
          final rounds = roundRobinRounds(g.size);
          for (int rIdx = 0; rIdx < rounds.length; rIdx++) {
            for (final pair in rounds[rIdx]) {
              final i1 = teamOffset + pair[0];
              final i2 = teamOffset + pair[1];
              if (i1 >= d.teams.length || i2 >= d.teams.length) continue;
              final nextNum = (matchNumByVenue[divVenueId] ?? 0) + 1;
              matchNumByVenue[divVenueId] = nextNum;
              pending.add(_PendingMatch(
                division: d,
                divVenueId: divVenueId,
                group: g,
                roundIdx: rIdx,
                team1Index: i1,
                team2Index: i2,
                matchNum: nextNum,
              ));
            }
          }
          teamOffset += g.size;
        }
      }

      final courtFree = <String, List<int>>{};
      for (final v in s._venues) {
        courtFree[v.id] = List<int>.filled(v.courts, baseMin);
      }
      final playerFree = <String, int>{};

      int curMin = baseMin;
      const safetyLimit = 24 * 60 * 7; // 한 일자 한계: 일주일치 분 (실제론 훨씬 일찍 종료)
      int iter = 0;
      while (pending.isNotEmpty && curMin <= safetyLimit) {
        iter++;
        if (iter > 200000) break;

        if (breakEnd > breakStart &&
            curMin >= breakStart &&
            curMin < breakEnd) {
          for (final v in s._venues) {
            final list = courtFree[v.id]!;
            for (int c = 0; c < list.length; c++) {
              if (list[c] < breakEnd) list[c] = breakEnd;
            }
          }
          curMin = breakEnd;
          continue;
        }

        for (final venue in s._venues) {
          final startCourt = _startCourtForVenue(venue.id);
          final cFreeList = courtFree[venue.id]!;

          String? activeGrade;
          int bestIdx = 1 << 30;
          for (final m in pending) {
            if (m.divVenueId != venue.id) continue;
            final gi = idxOf(gradePrio, m.division.grade);
            if (gi < bestIdx) {
              bestIdx = gi;
              activeGrade = m.division.grade;
            }
          }

          for (int c = 0; c < venue.courts; c++) {
            if (cFreeList[c] > curMin) continue;

            final mIdx = pending.indexWhere((m) {
              if (m.divVenueId != venue.id) return false;
              if (activeGrade != null && m.division.grade != activeGrade) {
                return false;
              }
              final t1 = m.division.teams[m.team1Index];
              final t2 = m.division.teams[m.team2Index];
              for (final p in [...t1.players, ...t2.players]) {
                if ((playerFree[p] ?? baseMin) > curMin) return false;
              }
              return true;
            });
            if (mIdx == -1) continue;

            final m = pending.removeAt(mIdx);
            final startMin = curMin;
            final endMin = startMin + matchMin;
            allRows.add(_ScheduleRow(
              time: fmtTime(startMin),
              globalCourt: startCourt + c,
              localCourt: c + 1,
              venueId: venue.id,
              division: m.division,
              groupName: m.group.name,
              matchNum: m.matchNum,
              team1: m.division.teams[m.team1Index],
              team2: m.division.teams[m.team2Index],
              dayIdx: day,
            ));
            for (final p in [
              ...m.division.teams[m.team1Index].players,
              ...m.division.teams[m.team2Index].players,
            ]) {
              playerFree[p] = endMin + restMin;
            }
            cFreeList[c] = endMin;
          }
        }

        curMin += matchMin;
      }
    }

    allRows.sort((a, b) {
      if (a.dayIdx != b.dayIdx) return a.dayIdx.compareTo(b.dayIdx);
      final ct = a.time.compareTo(b.time);
      if (ct != 0) return ct;
      return a.globalCourt.compareTo(b.globalCourt);
    });

    return allRows;
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.primaryMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    final venues = _activeVenues;
    if (venues.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '경기장이 없습니다.\n설정 탭에서 경기장과 코트를 추가하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      );
    }
    // venueId 보정 — 경기장 삭제 등으로 invalid 한 경우 첫 활성 경기장으로.
    if (_venueId == null || !venues.any((v) => v.id == _venueId)) {
      _venueId = venues.first.id;
      _localCourt = null;
    }
    final selVenue = venues.firstWhere((v) => v.id == _venueId);
    final totalDays = widget.s._totalDays;
    if (_dayFilter > totalDays) _dayFilter = 1;
    final allRows = _collectRows();
    final filtered = allRows.where((r) {
      if (r.venueId != _venueId) return false;
      if (_localCourt != null && r.localCourt != _localCourt) return false;
      if (totalDays > 1 && r.dayIdx != _dayFilter) return false;
      return true;
    }).toList();

    final dateText = switch (_dayFilter) {
      2 => widget.s._date2Ctrl.text,
      3 => widget.s._date3Ctrl.text,
      4 => widget.s._date4Ctrl.text,
      _ => widget.s._date1Ctrl.text,
    };
    return Container(
      color: AppColors.bg,
      child: Column(children: [
        // 경기 진행 우선순위(경기순서)는 설정 탭의 _PriorityCard 로 이관.
        // 일자 필터 — 다일 대회만 노출. 일자별 일정만 표시.
        if (totalDays > 1)
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int d = 1; d <= totalDays; d++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _dayFilter = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: _dayFilter == d
                                ? const Color(0xFF3730A3)
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: _dayFilter == d
                                  ? const Color(0xFF3730A3)
                                  : AppColors.gray2,
                              width: 1.3,
                            ),
                          ),
                          child: Text('$d일차',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _dayFilter == d
                                    ? Colors.white
                                    : AppColors.text2,
                                letterSpacing: -0.2,
                              )),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // 경기장 캡슐
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: venues.map((v) {
                final on = v.id == _venueId;
                final color = _hexToColor(v.colorHex);
                final name = v.name.isEmpty
                    ? '경기장 ${widget.s._venues.indexOf(v) + 1}'
                    : v.name;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _venueId = v.id;
                      _localCourt = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: on ? color : AppColors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color, width: 1.4),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : color,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // 코트 그리드
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _courtChip(
                  label: '전체',
                  selected: _localCourt == null,
                  onTap: () => setState(() => _localCourt = null)),
              for (int c = 1; c <= selVenue.courts; c++)
                _courtChip(
                  label: '$c코트',
                  selected: _localCourt == c,
                  onTap: () => setState(() => _localCourt = c),
                ),
            ],
          ),
        ),
        Container(height: 6, color: AppColors.bg),
        // 일정 리스트
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '표시할 경기가 없습니다.\n대진표를 먼저 생성하세요.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    4,
                    12,
                    14 + MediaQuery.of(context).padding.bottom,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ScheduleRowCard(
                    row: filtered[i],
                    dateText: dateText,
                    state: widget.s,
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _courtChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding:
              const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryMid : AppColors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected ? AppColors.primaryMid : AppColors.gray2,
              width: 1.3,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.text2,
              letterSpacing: -0.2,
            ),
          ),
        ),
      );

  // 경기 진행 순서(_buildPriorityBars 등)는 설정 탭의 _PriorityCard 로 이관됨.
  // _showSchedulePlayerSearch (선수 일정 검색) 은 협회 운영용 앱 요구사항에
  // 맞지 않아 제거. 동호인용 실시간 조회 화면이 별도로 만들어지면 그쪽에서 처리.
  /* removed: 선수 이름으로 본인의 모든 경기를 찾아 시간/코트/경기장과 함께 표시.
  void _xxx_unused(
      BuildContext context, List<_ScheduleRow> allRows) {
    final ctrl = TextEditingController();
    // 등록된 선수들의 이름 후보 (자동완성용).
    final allNames = <String>{};
    for (final r in allRows) {
      allNames.addAll(r.team1.players);
      allNames.addAll(r.team2.players);
    }
    final sortedNames = allNames.toList()..sort();

    final dateText = widget.s._date1Ctrl.text;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = ctrl.text.trim();
          final suggestions = q.isEmpty
              ? const <String>[]
              : sortedNames.where((n) => n.contains(q)).take(8).toList();
          // 정확히 일치하는 이름이 있으면 검색 결과 표시.
          final exactMatches = q.isEmpty
              ? const <_ScheduleRow>[]
              : allRows
                  .where((r) =>
                      r.team1.players.contains(q) ||
                      r.team2.players.contains(q))
                  .toList()
            ..sort((a, b) {
                final t = a.time.compareTo(b.time);
                if (t != 0) return t;
                return a.globalCourt.compareTo(b.globalCourt);
              });

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Column(children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  const Icon(Icons.person_search_rounded,
                      size: 22, color: Color(0xFF3730A3)),
                  const SizedBox(width: 8),
                  const Text('내 경기 찾기',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.3)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  onChanged: (_) => setSheetState(() {}),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text),
                  decoration: InputDecoration(
                    hintText: '이름 입력 (예: 홍길동)',
                    hintStyle: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                    prefixIcon:
                        const Icon(Icons.search, size: 20, color: AppColors.muted),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF3730A3), width: 1.5),
                    ),
                  ),
                ),
              ),
              // 검색어가 있고 정확 매칭이 없으면 자동완성 후보 표시.
              if (q.isNotEmpty && exactMatches.isEmpty && suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: suggestions
                        .map((n) => GestureDetector(
                              onTap: () {
                                ctrl.text = n;
                                ctrl.selection = TextSelection.fromPosition(
                                    TextPosition(offset: n.length));
                                setSheetState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(n,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF3730A3))),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: q.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '본인 이름을 입력하면\n경기시간 · 코트 · 경기장이 표시됩니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.muted,
                                height: 1.45),
                          ),
                        ),
                      )
                    : exactMatches.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                suggestions.isEmpty
                                    ? '"$q" 선수의 경기가 없습니다.\n이름을 정확히 입력해주세요.'
                                    : '"$q" 와(과) 일치하는 정확한 이름이 없습니다.\n위의 후보 중에서 선택하세요.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.muted,
                                    height: 1.45),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                                12, 8, 12, 20),
                            itemCount: exactMatches.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final r = exactMatches[i];
                              final venue = widget.s._venues.firstWhere(
                                  (v) => v.id == r.venueId,
                                  orElse: () => widget.s._venues.first);
                              final isOnTeam1 = r.team1.players.contains(q);
                              final myTeam = isOnTeam1 ? r.team1 : r.team2;
                              final oppTeam = isOnTeam1 ? r.team2 : r.team1;
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppColors.divider, width: 1),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                    12, 10, 12, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // 헤더: 날짜·시간 + 코트
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3730A3),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          r.time,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${r.localCourt}코트 · ${venue.name.isEmpty ? '경기장' : venue.name}',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.text,
                                              letterSpacing: -0.2),
                                        ),
                                      ),
                                      if (dateText.isNotEmpty)
                                        Text(
                                          dateText,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.muted),
                                        ),
                                    ]),
                                    const SizedBox(height: 6),
                                    // 종목·연령·급수·경기번호
                                    Text(
                                      '${r.division.event} ${r.division.ageGroup}-${r.division.grade} · ${r.groupName} ${r.matchNum}경기',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text2,
                                          letterSpacing: -0.1),
                                    ),
                                    const SizedBox(height: 8),
                                    // 본인팀 vs 상대팀
                                    Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text('본인',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(
                                                            0xFF3730A3))),
                                                const SizedBox(height: 2),
                                                Text(
                                                  myTeam.players.join(' · '),
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.text),
                                                ),
                                                Text(
                                                  myTeam.name.replaceAll(
                                                      '\n', ' / '),
                                                  style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color:
                                                          AppColors.muted,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 6),
                                            child: Text('vs',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: AppColors.muted)),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                const Text('상대',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            AppColors.muted)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  oppTeam.players.join(' · '),
                                                  textAlign: TextAlign.end,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.text),
                                                ),
                                                Text(
                                                  oppTeam.name.replaceAll(
                                                      '\n', ' / '),
                                                  textAlign: TextAlign.end,
                                                  style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color:
                                                          AppColors.muted,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ]),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ]),
          );
        },
      ),
    );
  }
  */
}

class _ScheduleRowCard extends StatefulWidget {
  final _ScheduleRow row;
  final String dateText;
  final _BracketScreenState state;
  const _ScheduleRowCard({
    required this.row,
    required this.dateText,
    required this.state,
  });

  @override
  State<_ScheduleRowCard> createState() => _ScheduleRowCardState();
}

class _ScheduleRowCardState extends State<_ScheduleRowCard> {
  final GlobalKey _shotKey = GlobalKey();
  bool _capturing = false;

  _ScheduleRow get row => widget.row;
  String get dateText => widget.dateText;

  String _shortDate(String s) {
    if (s.length == 10 && s[4] == '-' && s[7] == '-') {
      return s.substring(2);
    }
    return s;
  }

  /// 점수판/수동입력에서 회수된 실제 점수 (있으면). 없으면 null.
  /// 저장된 팀 IDs 가 현재 row 의 IDs 와 다르면 (페어 재배정) null 로 무효화.
  (int, int)? get _actualScore {
    final key = matchScoreKey(
      event: row.division.event,
      age: row.division.ageGroup,
      grade: row.division.grade,
      groupName: row.groupName,
      matchNum: row.matchNum,
    );
    final ms = widget.state._matchScores[key];
    return ms?.scoreFor(row.team1.playerIds, row.team2.playerIds);
  }

  /// 데모용 결정적 점수 — 실제 점수가 없을 때만 사용.
  ({int s1, int s2, bool t1Wins}) _sampleScore() {
    final actual = _actualScore;
    if (actual != null) {
      return (s1: actual.$1, s2: actual.$2, t1Wins: actual.$1 > actual.$2);
    }
    final i1 = row.team1.players.fold<int>(
        0, (a, b) => a + b.codeUnits.fold<int>(0, (x, y) => x + y));
    final i2 = row.team2.players.fold<int>(
        0, (a, b) => a + b.codeUnits.fold<int>(0, (x, y) => x + y));
    final seed = (row.matchNum * 31 + i1 * 7 + i2 * 13) & 0x7fffffff;
    final loser = 8 + (seed % 13);
    final t1Wins = seed.isEven;
    return (
      s1: t1Wins ? 21 : loser,
      s2: t1Wins ? loser : 21,
      t1Wins: t1Wins,
    );
  }

  /// 실제 점수가 입력됐는지 여부. 입력 전(점수판 미진행) → '예정'.
  bool get _isFinished => _actualScore != null;

  /// 이 매치에 승자 서명이 저장돼 있는지 — 카드 서명 버튼 아이콘 표시용.
  bool get _hasSignature {
    final key = matchScoreKey(
      event: row.division.event,
      age: row.division.ageGroup,
      grade: row.division.grade,
      groupName: row.groupName,
      matchNum: row.matchNum,
    );
    final ms = widget.state._matchScores[key];
    return ms != null && ms.winnerSignature.isNotEmpty;
  }

  /// 수동 점수 입력 — 점수판 없이 두 팀 점수를 다이얼로그로 직접 기록.
  /// 저장된 점수가 있으면 미리 채워서 표시.
  Future<void> _openManualInput() async {
    final existing = _actualScore;
    final c1 = TextEditingController(
        text: existing != null ? existing.$1.toString() : '');
    final c2 = TextEditingController(
        text: existing != null ? existing.$2.toString() : '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p1 = row.team1.players.join(' / ');
        final p2 = row.team2.players.join(' / ');
        InputDecoration deco(String hint) => InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 8),
              border: const OutlineInputBorder(),
            );
        return AlertDialog(
          title: const Text('점수 입력', style: TextStyle(fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      p1.isEmpty ? '팀1' : p1,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: c1,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800),
                      decoration: deco('0'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      p2.isEmpty ? '팀2' : p2,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: c2,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800),
                      decoration: deco('0'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소',
                    style: TextStyle(fontSize: 16))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('저장',
                    style: TextStyle(fontSize: 16))),
          ],
        );
      },
    );
    if (saved != true || !mounted) return;
    final sA = int.tryParse(c1.text.trim());
    final sB = int.tryParse(c2.text.trim());
    if (sA == null || sB == null) return;
    if (sA < 0 || sB < 0) return;
    final d = row.division;
    final key = matchScoreKey(
      event: d.event,
      age: d.ageGroup,
      grade: d.grade,
      groupName: row.groupName,
      matchNum: row.matchNum,
    );
    final uid = await widget.state._resolveUid();
    if (!mounted) return;
    // 기존 서명이 있으면 보존 — 점수만 갱신하면 서명 별도 입력 안 됨.
    final prior = widget.state._matchScores[key];
    final score = MatchScore(
      key: key,
      scoreA: sA,
      scoreB: sB,
      teamA: List<String>.from(row.team1.playerIds),
      teamB: List<String>.from(row.team2.playerIds),
      teamANames: List<String>.from(row.team1.players),
      teamBNames: List<String>.from(row.team2.players),
      createdBy: uid,
      winnerSignature: prior?.winnerSignature ?? '',
      winnerSide: prior?.winnerSide ?? '',
    );
    debugPrint(
        '[MatchScore] write manual $key uid=$uid sA=$sA sB=$sB');
    widget.state.rebuild(() {
      widget.state._matchScores[key] = score;
    });
    widget.state._saveMatchScores();
  }

  /// 점수판 진입 — 매치의 선수 4명을 자동 채우고, 결과를 회수해 카드에 반영.
  Future<void> _openScoreboard() async {
    final p1 = row.team1.players;
    final p2 = row.team2.players;
    final d = row.division;
    final venue = widget.state._venues.firstWhere(
        (v) => v.id == row.venueId,
        orElse: () => widget.state._venues.first);
    final venueLabel = venue.name.isNotEmpty ? ' (${venue.name})' : '';
    final ctx = '${d.event} ${d.ageGroup}-${d.grade} · '
        '${row.localCourt}코트 ${row.matchNum}경기$venueLabel';
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ScoreboardPage(
          initialLeftPlayer1: p1.isNotEmpty ? p1[0] : null,
          initialLeftPlayer2: p1.length > 1 ? p1[1] : null,
          initialRightPlayer1: p2.isNotEmpty ? p2[0] : null,
          initialRightPlayer2: p2.length > 1 ? p2[1] : null,
          contextLabel: ctx,
        ),
      ),
    );
    debugPrint(
        '[ScBoard] returned result=$result rowMounted=$mounted stateMounted=${widget.state.mounted}');

    // ── 점수 저장 즉시 처리 (polling/mounted 영향 X) ──────────────────────
    // 옛 흐름은 portrait polling 2초 후 저장 시도 → 그 사이 widget tree dispose
    // 되면 mounted=false 로 빠져 저장 누락. result 받자마자 widget 상태 무관하게
    // 저장만 먼저 수행, UI rebuild 는 mounted 일 때만.
    if (result != null) {
      final sA = result['scoreA'];
      final sB = result['scoreB'];
      if (sA is int &&
          sB is int &&
          !(sA == 0 && sB == 0)) {
        try {
          final key = matchScoreKey(
            event: d.event,
            age: d.ageGroup,
            grade: d.grade,
            groupName: row.groupName,
            matchNum: row.matchNum,
          );
          final uid = await widget.state._resolveUid();
          final newSig = result['winnerSignature'] as String? ?? '';
          final newSide = result['winnerSide'] as String? ?? '';
          final existing = widget.state._matchScores[key];
          final score = MatchScore(
            key: key,
            scoreA: sA,
            scoreB: sB,
            teamA: List<String>.from(row.team1.playerIds),
            teamB: List<String>.from(row.team2.playerIds),
            teamANames: List<String>.from(row.team1.players),
            teamBNames: List<String>.from(row.team2.players),
            createdBy: uid,
            winnerSignature: newSig.isNotEmpty
                ? newSig
                : (existing?.winnerSignature ?? ''),
            winnerSide:
                newSide.isNotEmpty ? newSide : (existing?.winnerSide ?? ''),
          );
          debugPrint(
              '[MatchScore] write scoreboard $key uid=$uid sA=$sA sB=$sB sigLen=${newSig.length}');
          // 직접 modify + 저장 (setState 호출 안 함 — state mounted 여부 무관).
          widget.state._matchScores[key] = score;
          widget.state._saveMatchScores();
        } catch (e) {
          debugPrint('[MatchScore] save FAILED: $e');
        }
      } else {
        debugPrint(
            '[MatchScore] skip (sA=$sA sB=$sB) — invalid type or 0-0');
      }
    }

    // ── UI rebuild (회전 정착 후) — 저장 끝났으므로 mounted 영향 없음 ────
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final waitStart = DateTime.now();
    while (DateTime.now().difference(waitStart) <
        const Duration(seconds: 2)) {
      final view =
          WidgetsBinding.instance.platformDispatcher.views.first;
      final s = view.physicalSize;
      if (s.height > s.width) break;
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (widget.state.mounted) {
      widget.state.rebuild(() {}); // BracketScreen 강제 리빌드 (UI 업데이트)
    }
    if (mounted) setState(() {});
    // (옛 autoOpenSignature 자동 호출 분기 제거 — 서명은 점수판 안에서 받음.)
  }

  /// 서명 다이얼로그 — 카드 버튼에서 호출. 현재 점수 기준으로 승자 판정 후 서명.
  /// 점수 없으면 안내, 무승부면 안내, 정상 시 다이얼로그 → MatchScore 의 서명 필드만 갱신.
  Future<void> _openSignature() async {
    final d = row.division;
    final key = matchScoreKey(
      event: d.event,
      age: d.ageGroup,
      grade: d.grade,
      groupName: row.groupName,
      matchNum: row.matchNum,
    );
    final existing = widget.state._matchScores[key];
    if (existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        duration: Duration(seconds: 1),
        content: Text('먼저 점수를 입력하세요.'),
      ));
      return;
    }
    // 기존 점수의 팀 구성 기준으로 라벨. 페어 변경된 경우 scoreFor 가 null 이지만,
    // 서명은 저장된 점수의 팀에 대해 받는 게 의미상 맞음.
    final teamALabel = existing.teamANames.isNotEmpty
        ? existing.teamANames.join(' · ')
        : row.team1.players.join(' · ');
    final teamBLabel = existing.teamBNames.isNotEmpty
        ? existing.teamBNames.join(' · ')
        : row.team2.players.join(' · ');
    // 이미 서명돼 있으면 보기 다이얼로그 먼저 — 사용자가 '다시 서명' 선택하면 입력 패드로 진행.
    if (existing.winnerSignature.isNotEmpty) {
      final wantReSign = await showSavedSignatureDialog(
        context,
        signatureDataUrl: existing.winnerSignature,
        scoreA: existing.scoreA,
        scoreB: existing.scoreB,
        winnerSide: existing.winnerSide,
        winnerLabel:
            existing.winnerSide == 'A' ? teamALabel : teamBLabel,
      );
      if (!mounted || !wantReSign) return;
    }
    final sig = await showWinnerSignatureDialog(
      context,
      scoreA: existing.scoreA,
      scoreB: existing.scoreB,
      teamALabel: teamALabel,
      teamBLabel: teamBLabel,
    );
    if (sig == null || !mounted) return;
    if (sig.winnerSide.isEmpty) {
      // 무승부 케이스 — 다이얼로그가 즉시 스킵됐을 때.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        duration: Duration(seconds: 1),
        content: Text('무승부 매치는 서명을 받지 않습니다.'),
      ));
      return;
    }
    final updated = MatchScore(
      key: existing.key,
      scoreA: existing.scoreA,
      scoreB: existing.scoreB,
      teamA: existing.teamA,
      teamB: existing.teamB,
      teamANames: existing.teamANames,
      teamBNames: existing.teamBNames,
      createdBy: existing.createdBy,
      winnerSignature: sig.signature,
      winnerSide: sig.winnerSide,
    );
    debugPrint(
        '[MatchScore] write signature $key winnerSide=${updated.winnerSide} sigBytes=${updated.winnerSignature.length}');
    widget.state.rebuild(() {
      widget.state._matchScores[key] = updated;
    });
    widget.state._saveMatchScores();
    AnalyticsService.signatureSave(tournamentId: widget.state._tournament.id);
  }

  /// 작은 액션 버튼 (점수판/공유 공용).
  Widget _smallButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: AppColors.primaryMid.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primaryMid),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryMid,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 카드 영역을 PNG 이미지로 캡처해 시스템 공유 시트로 전달.
  /// 캡처 직전 공유 버튼은 잠시 숨겨서 결과 이미지에 포함되지 않게 함.
  Future<void> _shareCard() async {
    try {
      setState(() => _capturing = true);
      // 다음 프레임 완료 대기 — 공유 버튼이 사라진 상태로 렌더되도록 보장.
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _shotKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (mounted) setState(() => _capturing = false);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File(
          '${tempDir.path}/match_${row.matchNum}_$ts.png');
      await file.writeAsBytes(pngBytes);
      final d = row.division;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${d.event} ${d.ageGroup}-${d.grade} ${row.groupName}',
      );
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = row.division;
    final title = '${d.event} ${d.ageGroup}-${d.grade}[${row.groupName}]';
    return RepaintBoundary(
      key: _shotKey,
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Container(
          color: AppColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 행:
              //  - 왼쪽: 시각 + (그 아래) 일자
              //  - 중앙: 체육관 이름 (캡처/공유 시에만 노출, 우측 정렬)
              //  - 오른쪽: 상태 박스(예정/경기종료)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          row.time,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.text,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          _shortDate(dateText),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 상단 행 중앙: (캡처시) 체육관 이름 → 1코트 N경기 순으로.
                  // 화면(non-capture)에서는 체육관 이름이 없으므로 1코트만 보임.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 30, right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_capturing)
                            Builder(builder: (_) {
                              final venues = widget.state._venues;
                              if (venues.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final v = venues.firstWhere(
                                (e) => e.id == row.venueId,
                                orElse: () => venues.first,
                              );
                              if (v.name.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  v.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.muted,
                                  ),
                                ),
                              );
                            }),
                          Text(
                            '${row.localCourt}코트 ${row.matchNum}경기',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    color: _isFinished
                        ? AppColors.primaryMid
                        : AppColors.green2,
                    child: Text(
                      _isFinished ? '경기종료' : '예정',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _matchupRow(),
                    // 점수 아래 좌/우 액션 버튼 — 캡처 시 숨김.
                    if (!_capturing) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        _smallButton(
                          icon: Icons.scoreboard,
                          label: '점수판',
                          onTap: _openScoreboard,
                        ),
                        const SizedBox(width: 6),
                        _smallButton(
                          icon: Icons.edit,
                          label: '수동입력',
                          onTap: _openManualInput,
                        ),
                        const SizedBox(width: 6),
                        _smallButton(
                          icon: _hasSignature
                              ? Icons.check_circle
                              : Icons.draw_outlined,
                          label: '서명',
                          onTap: _openSignature,
                        ),
                        const Spacer(),
                        _smallButton(
                          icon: Icons.share,
                          label: '공유',
                          onTap: _shareCard,
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// 팀1 vs 팀2 행. 종료된 경기는 양쪽 팀 옆에 각자 점수를 크게 표시.
  /// 점수는 선수 두 이름 중간 높이로 정렬 (CrossAxisAlignment.start + top padding).
  Widget _matchupRow() {
    if (!_isFinished) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _teamView(row.team1, alignEnd: false)),
          const Padding(
            padding: EdgeInsets.only(left: 12, right: 12, top: 6),
            child: Text(
              'vs',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryMid,
              ),
            ),
          ),
          Expanded(child: _teamView(row.team2, alignEnd: true)),
        ],
      );
    }
    final score = _sampleScore();
    const winnerBlue = Color(0xFF2563EB);
    Color colorFor(bool wins) => wins ? winnerBlue : AppColors.muted;
    TextStyle scoreStyle(bool wins) => TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: colorFor(wins),
          height: 1.0,
          letterSpacing: -0.5,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _teamView(row.team1, alignEnd: false)),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${score.s1}', style: scoreStyle(score.t1Wins)),
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${score.s2}', style: scoreStyle(!score.t1Wins)),
        ),
        const SizedBox(width: 6),
        Expanded(child: _teamView(row.team2, alignEnd: true)),
      ],
    );
  }

  Widget _teamView(TeamData t, {required bool alignEnd}) {
    // 클럽명 줄바꿈 처리 — 동일 클럽(혹은 잘려서 같아진 경우) 중복 표시 제거.
    final clubLines =
        t.name.split('\n').toSet().toList(); // 순서 유지하며 dedupe
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (final p in t.players)
          Text(
            p,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              letterSpacing: -0.3,
              height: 1.2,
            ),
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          ),
        const SizedBox(height: 4),
        for (final line in clubLines)
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              letterSpacing: -0.2,
            ),
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TAB 5: 입상자
// ═══════════════════════════════════════════════════════
class _ResultsTab extends StatelessWidget {
  final _BracketScreenState s;
  const _ResultsTab(this.s);

  /// 각 division 의 각 group 별로 순위 산출 → 상위 3팀을 _WinnerData 로.
  /// 정렬 기준은 _DivisionCard._rankingTable 과 동일 (다승→승자승→다득점→득실차).
  List<_WinnerData> _computeWinners() {
    final out = <_WinnerData>[];
    for (final d in s._tournament.divisions) {
      final fmt = d.format;
      for (int gi = 0; gi < fmt.groups.length; gi++) {
        final g = fmt.groups[gi];
        // 조별 팀 슬라이스 (_DivisionCard._teamsForGroup 와 동일 로직).
        int start = 0;
        for (int i = 0; i < gi; i++) {
          start += fmt.groups[i].size;
        }
        final end = (start + g.size).clamp(0, d.teams.length);
        if (start >= d.teams.length) continue;
        final teams = d.teams.sublist(
            start.clamp(0, d.teams.length), end);
        if (teams.length < 2) continue;
        final matches = generateMatches(group: g, courts: 1);

        // 통계 집계.
        final n = teams.length;
        final wins = List.filled(n, 0);
        final pf = List.filled(n, 0);
        final pa = List.filled(n, 0);
        final h2h = List.generate(n, (_) => List.filled(n, 0));
        int playedCount = 0;
        for (final m in matches) {
          if (m.team1Index >= n || m.team2Index >= n) continue;
          final key = matchScoreKey(
            event: d.event,
            age: d.ageGroup,
            grade: d.grade,
            groupName: g.name,
            matchNum: m.num_,
          );
          final pair = s._matchScores[key]?.scoreFor(
            teams[m.team1Index].playerIds,
            teams[m.team2Index].playerIds,
          );
          if (pair == null) continue;
          playedCount++;
          final s1 = pair.$1;
          final s2 = pair.$2;
          pf[m.team1Index] += s1;
          pa[m.team1Index] += s2;
          pf[m.team2Index] += s2;
          pa[m.team2Index] += s1;
          if (s1 > s2) {
            wins[m.team1Index]++;
            h2h[m.team1Index][m.team2Index]++;
          } else if (s2 > s1) {
            wins[m.team2Index]++;
            h2h[m.team2Index][m.team1Index]++;
          }
        }
        // 매치 1개도 안 치러진 조는 입상자 미산출.
        if (playedCount == 0) continue;
        final order = List.generate(n, (i) => i);
        order.sort((a, b) {
          if (wins[a] != wins[b]) return wins[b].compareTo(wins[a]);
          if (h2h[a][b] != h2h[b][a]) {
            return h2h[b][a].compareTo(h2h[a][b]);
          }
          if (pf[a] != pf[b]) return pf[b].compareTo(pf[a]);
          final diffA = pf[a] - pa[a];
          final diffB = pf[b] - pa[b];
          return diffB.compareTo(diffA);
        });
        _Podium podium(int rank) {
          if (rank >= order.length) {
            return const _Podium(club: '-', players: '-');
          }
          final t = teams[order[rank]];
          return _Podium(
            club: t.name.replaceAll('\n', ' / '),
            players: t.players.join(' / '),
          );
        }

        final groupSuffix = fmt.groups.length > 1 ? ' ${g.name}' : '';
        out.add(_WinnerData(
          division: '${d.event} ${d.ageGroup}-${d.grade}$groupSuffix',
          first: podium(0),
          second: podium(1),
          third: podium(2),
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final winners = _computeWinners();
    if (winners.isEmpty) {
      return Container(
        color: AppColors.bg,
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '아직 입상자가 없습니다.\n경기시간 탭에서 점수를 입력하면 자동 산출됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.45),
          ),
        ),
      );
    }
    return Container(
      color: AppColors.bg,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: winners.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _WinnerCard(data: winners[i]),
      ),
    );
  }
}

class _Podium {
  final String club;
  final String players;
  const _Podium({required this.club, required this.players});
}

class _WinnerData {
  final String division;
  final _Podium first;
  final _Podium second;
  final _Podium third;
  const _WinnerData({
    required this.division,
    required this.first,
    required this.second,
    required this.third,
  });
}

class _WinnerCard extends StatefulWidget {
  final _WinnerData data;
  const _WinnerCard({required this.data});

  @override
  State<_WinnerCard> createState() => _WinnerCardState();
}

class _WinnerCardState extends State<_WinnerCard> {
  final GlobalKey _shotKey = GlobalKey();
  bool _capturing = false;

  static const _gold = Color(0xFFD4A017);
  static const _silver = Color(0xFF8E8E93);
  static const _bronze = Color(0xFFB08D57);

  _WinnerData get data => widget.data;

  /// 카드 영역을 PNG 이미지로 캡처해 공유 시트에 전달.
  /// 캡처 시 공유 버튼은 잠시 숨겨 결과 이미지에 포함되지 않게 함.
  Future<void> _shareCard() async {
    try {
      setState(() => _capturing = true);
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _shotKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) setState(() => _capturing = false);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (mounted) setState(() => _capturing = false);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/winner_$ts.png');
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${data.division} 입상자',
      );
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Widget _shareButton() => GestureDetector(
        onTap: _shareCard,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.primaryMid.withValues(alpha: 0.25),
                width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.share, size: 14, color: AppColors.primaryMid),
              SizedBox(width: 5),
              Text(
                '공유',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryMid,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _row(int rank, Color color, _Podium p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.players,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.club,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.emoji_events, color: color, size: 22),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _shotKey,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.4),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.division,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryMid,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const Spacer(),
              // 캡처 시 공유 버튼은 숨겨 결과 이미지에 미포함.
              if (!_capturing) _shareButton(),
            ]),
            const Divider(height: 16, color: AppColors.divider),
            _row(1, _gold, data.first),
            _row(2, _silver, data.second),
            _row(3, _bronze, data.third),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  공통 헬퍼 함수
// ═══════════════════════════════════════════════════════
Widget _card(
        {required String title, String? subtitle, required Widget child}) =>
    Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          // 파스텔 블루 보더 — 대회운영 카드와 톤 통일
          border: Border.all(color: const Color(0xFFB8C9F0), width: 2.5)),
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text2)),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted)),
            ),
          ],
        ]),
        const SizedBox(height: 4),
        child,
      ]),
    );

// ═══════════════════════════════════════════════════════
//  등급별 종목 요약 (BottomSheet) — (종목·연령·급수)별 팀 수.
// ═══════════════════════════════════════════════════════
void _showGradeSummary(BuildContext context, _BracketScreenState s) {
  // 선택된 참가자 + 활성 칩 기준으로 (event, age, grade) 별 팀 수 집계.
  final selPlayers = SampleData.players
      .where((p) => s._selected.contains(p.id))
      .toList();
  final ages = s._ageGroupLabels.where(s._activeAgeGroups.contains).toList();
  final grades = s._gradeGroupLabels.where(s._activeGrades.contains).toList();
  const events = ['혼복', '남복', '여복'];

  bool genderOk(Player p, String e) {
    if (e == '남복') return p.gender == '남';
    if (e == '여복') return p.gender == '여';
    return true;
  }

  final rows =
      <(String event, String age, String grade, int teams, FormatRecommendation rec)>[];
  for (final e in events) {
    for (final a in ages) {
      for (final g in grades) {
        final pool = selPlayers
            .where((p) => genderOk(p, e))
            .where((p) => p.grade == g)
            .where((p) => ageMatches(a, p.age, s._ageGroupLabels))
            .length;
        if (pool < 2) continue;
        final teams = pool ~/ 2; // 복식: 2명 한 팀
        if (teams < 3) continue; // 3팀 미만은 부서 미생성
        rows.add((e, a, g, teams, recommendFormat(teams)));
      }
    }
  }
  final totalParticipants = selPlayers.length;
  final tier = tournamentScaleTier(totalParticipants);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('등급별 참가팀',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  const SizedBox(width: 8),
                  Text('총 ${rows.length}종 · $totalParticipants명',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                ]),
                if (totalParticipants > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(tier,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryMid,
                            letterSpacing: -0.1)),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '집계할 종목이 없습니다.\n참가자 선택 + 연령/급수 칩을 활성화하세요.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 2),
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final rec = r.$5;
                      return Container(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  '${r.$1} ${r.$2}-${r.$3}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${r.$4}팀',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryMid,
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: rec.supportedNow
                                      ? const Color(0xFFE0F2FE)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rec.supportedNow
                                      ? '권장: ${rec.label}'
                                      : '권장: ${rec.label} (미구현)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: rec.supportedNow
                                        ? const Color(0xFF0369A1)
                                        : const Color(0xFF92400E),
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rec.reason,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                      letterSpacing: -0.1),
                                ),
                              ),
                            ]),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════
//  선수 검색 (BottomSheet) — 이름/클럽으로 빠른 조회.
// ═══════════════════════════════════════════════════════
void _showPlayerSearch(BuildContext context, _BracketScreenState s) {
  final ctrl = TextEditingController();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final q = ctrl.text.trim();
        final list = q.isEmpty
            ? const <Player>[]
            : SampleData.players.where((p) {
                if (p.name.contains(q)) return true;
                if (p.clubName.contains(q)) return true;
                return false;
              }).take(50).toList();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  onChanged: (_) => setSheetState(() {}),
                  decoration: InputDecoration(
                    hintText: '선수 이름 또는 클럽명 검색',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: q.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            '검색어를 입력하세요.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.muted),
                          ),
                        ),
                      )
                    : list.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                '일치하는 선수가 없습니다.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.muted),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                                10, 4, 10, 10),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 2),
                            itemBuilder: (_, i) {
                              final p = list[i];
                              final selected = s._selected.contains(p.id);
                              return GestureDetector(
                                onTap: () {
                                  s.rebuild(() {
                                    if (selected) {
                                      s._removeFromSelection([p.id]);
                                    } else {
                                      s._addToSelection([p.id]);
                                    }
                                  });
                                  setSheetState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primaryLight
                                        : AppColors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.primaryMid
                                          : const Color(0xFFCBD5E1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${p.name} · ${p.age}세 · ${p.gender}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.text,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '${p.grade} · '
                                            '${p.clubName.isEmpty ? '무소속' : p.clubName}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: selected
                                          ? AppColors.primaryMid
                                          : AppColors.gray3,
                                      size: 22,
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════
//  클럽별 참가자 조회 (BottomSheet)
// ═══════════════════════════════════════════════════════
void _showClubLookup(BuildContext context, _BracketScreenState s) {
  final selPlayers = SampleData.players
      .where((p) => s._selected.contains(p.id))
      .toList();

  // 클럽명 → 선수 목록
  final byClub = <String, List<Player>>{};
  for (final p in selPlayers) {
    final key = p.clubName.trim().isEmpty ? '(소속 미지정)' : p.clubName.trim();
    byClub.putIfAbsent(key, () => []).add(p);
  }
  final clubNames = byClub.keys.toList()..sort();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      final maxH = mq.size.height * 0.78;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Text('클럽별 참가자',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text)),
                const SizedBox(width: 8),
                Text('${selPlayers.length}명 · ${clubNames.length}개 클럽',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            if (s._entryEventCounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  _formatEventCounts(s._entryEventCounts),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text2),
                ),
              ),
            const SizedBox(height: 6),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: clubNames.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('선택된 참가자가 없습니다.',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                          12, 10, 12, 12 + mq.padding.bottom),
                      itemCount: clubNames.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final club = clubNames[i];
                        // 정렬: 급수(자강조→초심조) → 나이 어린 순 → 이름.
                        final players = byClub[club]!
                          ..sort((a, b) {
                            final g = a.gradeIndex.compareTo(b.gradeIndex);
                            if (g != 0) return g;
                            final ag = a.age.compareTo(b.age);
                            if (ag != 0) return ag;
                            return a.name.compareTo(b.name);
                          });
                        return _ClubLookupSection(
                            club: club, players: players);
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );
}

String _formatEventCounts(Map<String, int> counts) {
  final order = ['혼복', '남복', '여복'];
  final parts = <String>[];
  for (final k in order) {
    final n = counts[k] ?? 0;
    if (n == 0) continue;
    final num = (n / 2).ceil();
    parts.add('$k $num쌍');
  }
  return parts.isEmpty ? '' : parts.join(' · ');
}

/// 참가자 추가 진입점 — 직접 입력/엑셀 일괄 등록 모두 [ParticipantAddScreen] 으로
/// 단일화. 결과 [EntryUploadResult] 를 받아 `_selected` 와 `_entryEventCounts` 에
/// 머지하고 즉시 영속화.
Future<void> _onParticipantAdd(
    BuildContext context, _BracketScreenState s) async {
  final result = await Navigator.push<EntryUploadResult>(
    context,
    MaterialPageRoute(
      builder: (_) => ParticipantAddScreen(
        existingSelected: s._selected,
        initialGrades: s._gradeGroupLabels,
        onAddGrade: s._addGradeGroup,
        onRemoveGrade: s._removeGradeGroup,
      ),
    ),
  );
  if (result == null) return;
  s.rebuild(() {
    // _replaceSelection 이 Firestore tournamentIds 동기화 + SP 캐시 저장까지 담당.
    s._replaceSelection(result.selectedPlayerIds);
    final merged = <String, int>{...s._entryEventCounts};
    result.eventCounts.forEach((k, v) {
      merged[k] = (merged[k] ?? 0) + v;
    });
    s._entryEventCounts = merged;
  });
  StorageService.saveBracketEntryEventCounts(
      s._tournament.id, s._entryEventCounts);
}

class _PillBtn extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final Color? bg;
  final Color? fg;
  final EdgeInsets? padding;
  final double? fontSize;
  final double? iconSize;
  const _PillBtn({
    this.icon,
    required this.label,
    required this.onTap,
    this.bg,
    this.fg,
    this.padding,
    this.fontSize,
    this.iconSize,
  });
  @override
  Widget build(BuildContext context) {
    final bgColor = bg ?? AppColors.primaryMid;
    final fgColor = fg ?? Colors.white;
    final style = OutlinedButton.styleFrom(
      foregroundColor: fgColor,
      backgroundColor: bgColor,
      side: BorderSide(color: bgColor, width: 1.4),
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: TextStyle(
        fontSize: fontSize ?? 13,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
    final labelText = Text(label, style: TextStyle(color: fgColor));
    if (icon == null) {
      return OutlinedButton(onPressed: onTap, style: style, child: labelText);
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: iconSize ?? 18, color: fgColor),
      label: labelText,
      style: style,
    );
  }
}

class _ClubLookupSection extends StatelessWidget {
  final String club;
  final List<Player> players;
  const _ClubLookupSection({required this.club, required this.players});

  @override
  Widget build(BuildContext context) {
    // 급수별 그룹 — 자강조→초심조 순서. 같은 급수 내에서는 호출자가 정렬한 순서 유지.
    final byGrade = <String, List<Player>>{};
    for (final p in players) {
      byGrade.putIfAbsent(p.grade, () => []).add(p);
    }
    final orderedGrades = byGrade.keys.toList()
      ..sort((a, b) =>
          (Player.gradeOrder[a] ?? 99).compareTo(Player.gradeOrder[b] ?? 99));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D9E6), width: 1.2),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(club,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
            ),
            Text('${players.length}명',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
          ]),
          const SizedBox(height: 6),
          for (final g in orderedGrades)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.gradeLightBg(g),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gradeLightText(g),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      byGrade[g]!.map((p) => p.name).join(', '),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                          height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

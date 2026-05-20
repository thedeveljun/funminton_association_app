import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:badminton_association/score/enums/serve_side.dart';
import 'package:badminton_association/score/l10n/app_locale.dart';
import 'package:badminton_association/score/l10n/app_strings.dart';
import 'package:badminton_association/score/l10n/locale_controller.dart';
import 'package:badminton_association/score/models/game_snapshot.dart';
import 'package:badminton_association/score/models/result_models.dart';
import 'package:badminton_association/score/models/saved_match_record.dart';
import 'package:badminton_association/score/pages/saved_matches_page.dart';
import 'package:badminton_association/score/pages/bulk_player_edit_page.dart';

/// 게임 상태 + 로직 (추상 클래스)
abstract class ScoreboardState<T extends StatefulWidget> extends State<T> {
  static const String savedMatchesKey = 'saved_matches_v1';

  /// 저장될 경기에 같이 기록할 컨텍스트 라벨(종목/연령/급수/코트/경기장).
  /// 서브클래스에서 widget.contextLabel 등으로 노출.
  String get matchContextLabel => '';

  List<SavedMatchRecord> savedMatches = [];

  // 현재 로케일 기반 문자열 헬퍼
  S get s => S(LocaleController.notifier.value);

  // ── TTS ──────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _ttsEnabled = true;
  bool _ttsReady = false;

  Future<void> initTts() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _tts.setSharedInstance(true).catchError((_) {});
      }

      await _tts.setLanguage(LocaleController.notifier.value.ttsCode);
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);

      _ttsReady = true;
      debugPrint('🔊 [TTS] 초기화 성공!');
    } catch (e) {
      debugPrint('🔊 [TTS] 초기화 실패: $e');
      _ttsReady = false;
    }
  }

  Future<void> disposeTts() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _onLocaleChanged() async {
    try {
      await _tts.stop();
      await _tts.setLanguage(LocaleController.notifier.value.ttsCode);
    } catch (e) {
      debugPrint('🔊 [TTS] 언어 변경 실패: $e');
    }
    if (mounted) setState(() {});
  }

  void toggleTts() {
    _ttsEnabled = !_ttsEnabled;
    if (!_ttsEnabled) _tts.stop();
  }

  bool get ttsEnabled => _ttsEnabled;

  void _speak(String text) {
    if (!_ttsEnabled) return;
    if (!_ttsReady) {
      initTts().then((_) => _tts.speak(text)).catchError((e) {
        debugPrint('🔊 [TTS] init+speak 실패: $e');
        return 1;
      });
      return;
    }
    _tts.stop().then((_) => _tts.speak(text)).catchError((e) {
      debugPrint('🔊 [TTS] speak 실패: $e');
      return 1;
    });
  }

  int scoreA = 0;
  int scoreB = 0;
  int targetScore = 25;
  bool useDeuce = false;

  // 내부 sentinel 값(저장값). 표시는 S.localizedPlayerName으로 변환.
  String leftPlayer1 = '선수1';
  String leftPlayer2 = '선수2';
  String rightPlayer1 = '선수3';
  String rightPlayer2 = '선수4';

  ServeSide servingSide = ServeSide.left;

  int leftCurrentServerIndex = 0;
  int rightCurrentServerIndex = 0;
  int leftLastServerIndex = 0;
  int rightLastServerIndex = 0;
  int leftInitialServerIndex = 0;
  int rightInitialServerIndex = 0;

  bool leftHasServed = false;
  bool rightHasServed = false;

  // ★ 코트체인지 한 번만 안내 (게임당 1회 보장)
  bool _courtChangeAnnounced = false;

  final List<GameSnapshot> scoreHistory = [];

  // ── 서브 상태 getters ─────────────────────────────────────────
  bool get isLeftPlayer1Serving =>
      leftHasServed &&
      servingSide == ServeSide.left &&
      leftCurrentServerIndex == 0;
  bool get isLeftPlayer2Serving =>
      leftHasServed &&
      servingSide == ServeSide.left &&
      leftCurrentServerIndex == 1;
  bool get isRightPlayer1Serving =>
      rightHasServed &&
      servingSide == ServeSide.right &&
      rightCurrentServerIndex == 0;
  bool get isRightPlayer2Serving =>
      rightHasServed &&
      servingSide == ServeSide.right &&
      rightCurrentServerIndex == 1;

  // ── 선수 helpers ──────────────────────────────────────────────
  /// 표시용으로 현지화된 선수명 리스트.
  List<String> get allPlayers => [
        s.localizedPlayerName(leftPlayer1),
        s.localizedPlayerName(leftPlayer2),
        s.localizedPlayerName(rightPlayer1),
        s.localizedPlayerName(rightPlayer2),
      ];

  bool isLeftTeamGlobalIndex(int index) => index == 0 || index == 1;
  int toLocalIndex(int globalIndex) =>
      (globalIndex == 0 || globalIndex == 2) ? 0 : 1;
  List<int> opponentCandidatesOf(int firstServerGlobalIndex) =>
      isLeftTeamGlobalIndex(firstServerGlobalIndex) ? [2, 3] : [0, 1];

  bool _isPlaceholderLabel(String v) =>
      {'선수1', '선수2', '선수3', '선수4'}.contains(v.trim());
  String _normalizeName(String v) {
    final t = v.trim();
    return (t.isEmpty || _isPlaceholderLabel(t)) ? '' : t;
  }

  int get enteredPlayerCount => [
        leftPlayer1,
        leftPlayer2,
        rightPlayer1,
        rightPlayer2
      ].where((n) => _normalizeName(n).isNotEmpty).length;
  bool get canSaveMatch => enteredPlayerCount >= 2;
  // ★ 기록저장 활성화 기준: 15점 게임 → 8점, 21점 게임 → 11점, 25점 게임 → 13점 (하프점수)
  int get saveScoreThreshold {
    if (targetScore == 15) return 8;
    if (targetScore == 21) return 11;
    return 13;
  }
  bool get hasEnoughScoreToSave =>
      scoreA >= saveScoreThreshold || scoreB >= saveScoreThreshold;
  bool get saveEnabled => canSaveMatch && hasEnoughScoreToSave;
  String get deuceLabel => useDeuce ? s.deuceOn : s.deuceOff;

  bool isSameRecordIgnoringTime(SavedMatchRecord a, SavedMatchRecord b) =>
      a.leftPlayer1 == b.leftPlayer1 &&
      a.leftPlayer2 == b.leftPlayer2 &&
      a.rightPlayer1 == b.rightPlayer1 &&
      a.rightPlayer2 == b.rightPlayer2 &&
      a.scoreA == b.scoreA &&
      a.scoreB == b.scoreB &&
      a.targetScore == b.targetScore &&
      a.useDeuce == b.useDeuce;

  int get _courtChangePoint {
    if (targetScore == 15) return 8;
    if (targetScore == 21) return 11;
    return 13;
  }

  int get _maxScoreCap {
    if (targetScore == 15) return 24;
    if (targetScore == 21) return 30;
    return 31;
  }

  // ── Lifecycle ─────────────────────────────────────────────────
  void initScoreboard({
    String? initialLeftPlayer1,
    String? initialLeftPlayer2,
    String? initialRightPlayer1,
    String? initialRightPlayer2,
  }) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // 외부에서 선수명을 받았으면 sentinel 값을 덮어쓴다 (대회 매치 카드 진입 등).
    if (initialLeftPlayer1 != null && initialLeftPlayer1.trim().isNotEmpty) {
      leftPlayer1 = initialLeftPlayer1.trim();
    }
    if (initialLeftPlayer2 != null && initialLeftPlayer2.trim().isNotEmpty) {
      leftPlayer2 = initialLeftPlayer2.trim();
    }
    if (initialRightPlayer1 != null && initialRightPlayer1.trim().isNotEmpty) {
      rightPlayer1 = initialRightPlayer1.trim();
    }
    if (initialRightPlayer2 != null && initialRightPlayer2.trim().isNotEmpty) {
      rightPlayer2 = initialRightPlayer2.trim();
    }
    initTts();
    LocaleController.notifier.addListener(_onLocaleChanged);
    loadSavedMatches();
  }

  void disposeScoreboard() {
    LocaleController.notifier.removeListener(_onLocaleChanged);
    disposeTts();
    // 회전 제어는 ScoreboardPage 의 _exitFullscreen 이 단독 담당.
    // (여기서 4방향 모두 허용으로 풀면 dispose 중 잠깐 landscape 로 돌아가
    //  bracket_app 이 잘못된 metrics 로 첫 프레임을 그리는 버그가 발생함.)
  }

  // ── 저장/불러오기 ──────────────────────────────────────────────
  Future<void> loadSavedMatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(savedMatchesKey) ?? [];
      final loaded = <SavedMatchRecord>[];
      for (final raw in rawList) {
        try {
          loaded.add(SavedMatchRecord.fromMap(
              jsonDecode(raw) as Map<String, dynamic>));
        } catch (e) {
          debugPrint('💾 손상된 기록 1건 스킵: $e');
        }
      }
      if (!mounted) return;
      setState(() => savedMatches = loaded);
    } catch (e) {
      debugPrint('💾 loadSavedMatches 실패: $e');
    }
  }

  Future<void> saveCurrentMatch(String myTeamSide) async {
    final record = SavedMatchRecord(
      savedAt: DateTime.now().toIso8601String(),
      leftPlayer1: leftPlayer1,
      leftPlayer2: leftPlayer2,
      rightPlayer1: rightPlayer1,
      rightPlayer2: rightPlayer2,
      scoreA: scoreA,
      scoreB: scoreB,
      targetScore: targetScore,
      useDeuce: useDeuce,
      myTeamSide: myTeamSide,
      contextLabel: matchContextLabel,
    );

    if (savedMatches.isNotEmpty &&
        isSameRecordIgnoringTime(record, savedMatches.first)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.duplicateSaveBlocked),
          duration: const Duration(seconds: 1)));
      return;
    }

    final updated = [record, ...savedMatches];
    if (updated.length > 20) updated.removeRange(20, updated.length);

    bool success = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = updated.map((e) => jsonEncode(e.toMap())).toList();
      success = await prefs.setStringList(savedMatchesKey, encoded);
    } catch (e) {
      debugPrint('💾 saveCurrentMatch 실패: $e');
      success = false;
    }

    if (!mounted) return;
    if (success) {
      setState(() => savedMatches = updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.savedSuccess),
          duration: const Duration(seconds: 1)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.savedFailed),
          duration: const Duration(seconds: 1)));
    }
  }

  Future<void> openSavedMatchesPage() async {
    final result = await Navigator.push<SavedMatchesPageResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedMatchesPage(
          savedMatchesKey: savedMatchesKey,
          initialMatches: List<SavedMatchRecord>.from(savedMatches),
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result.changed) setState(() => savedMatches = result.savedMatches);
  }

  // ── 게임 로직 ─────────────────────────────────────────────────
  bool isGameFinished() {
    if (scoreA >= _maxScoreCap || scoreB >= _maxScoreCap) return true;
    if (!useDeuce) return scoreA >= targetScore || scoreB >= targetScore;
    final reached = scoreA >= targetScore || scoreB >= targetScore;
    return reached && (scoreA - scoreB).abs() >= 2;
  }

  void pushScoreSnapshot() {
    scoreHistory.add(GameSnapshot(
      scoreA: scoreA,
      scoreB: scoreB,
      servingSide: servingSide,
      leftCurrentServerIndex: leftCurrentServerIndex,
      rightCurrentServerIndex: rightCurrentServerIndex,
      leftLastServerIndex: leftLastServerIndex,
      rightLastServerIndex: rightLastServerIndex,
      leftInitialServerIndex: leftInitialServerIndex,
      rightInitialServerIndex: rightInitialServerIndex,
      leftHasServed: leftHasServed,
      rightHasServed: rightHasServed,
    ));
  }

  void undoLastScore() {
    if (scoreHistory.isEmpty) return;
    setState(() {
      final last = scoreHistory.removeLast();
      scoreA = last.scoreA;
      scoreB = last.scoreB;
      servingSide = last.servingSide;
      leftCurrentServerIndex = last.leftCurrentServerIndex;
      rightCurrentServerIndex = last.rightCurrentServerIndex;
      leftLastServerIndex = last.leftLastServerIndex;
      rightLastServerIndex = last.rightLastServerIndex;
      leftInitialServerIndex = last.leftInitialServerIndex;
      rightInitialServerIndex = last.rightInitialServerIndex;
      leftHasServed = last.leftHasServed;
      rightHasServed = last.rightHasServed;
    });
    if (scoreA < _courtChangePoint && scoreB < _courtChangePoint) {
      _courtChangeAnnounced = false;
    }
    _speak(s.ttsUndo);
  }

  void resetScores() {
    setState(() {
      scoreA = 0;
      scoreB = 0;
      servingSide = ServeSide.left;
      leftCurrentServerIndex = 0;
      rightCurrentServerIndex = 0;
      leftLastServerIndex = 0;
      rightLastServerIndex = 0;
      leftInitialServerIndex = 0;
      rightInitialServerIndex = 0;
      leftHasServed = false;
      rightHasServed = false;
      scoreHistory.clear();
    });
    _courtChangeAnnounced = false;
  }

  void giveServeToLeft() {
    servingSide = ServeSide.left;
    if (!leftHasServed) {
      leftCurrentServerIndex = leftInitialServerIndex;
      leftLastServerIndex = leftCurrentServerIndex;
      leftHasServed = true;
      return;
    }
    leftCurrentServerIndex = 1 - leftLastServerIndex;
    leftLastServerIndex = leftCurrentServerIndex;
  }

  void giveServeToRight() {
    servingSide = ServeSide.right;
    if (!rightHasServed) {
      rightCurrentServerIndex = rightInitialServerIndex;
      rightLastServerIndex = rightCurrentServerIndex;
      rightHasServed = true;
      return;
    }
    rightCurrentServerIndex = 1 - rightLastServerIndex;
    rightLastServerIndex = rightCurrentServerIndex;
  }

  void addScoreA() {
    if (isGameFinished()) return;
    setState(() {
      pushScoreSnapshot();
      scoreA++;
      if (servingSide == ServeSide.left) {
        leftLastServerIndex = leftCurrentServerIndex;
        leftHasServed = true;
      } else {
        giveServeToLeft();
      }
    });
    _announceScore();
    if (isGameFinished()) onGameJustFinished();
  }

  void addScoreB() {
    if (isGameFinished()) return;
    setState(() {
      pushScoreSnapshot();
      scoreB++;
      if (servingSide == ServeSide.right) {
        rightLastServerIndex = rightCurrentServerIndex;
        rightHasServed = true;
      } else {
        giveServeToRight();
      }
    });
    _announceScore();
    if (isGameFinished()) onGameJustFinished();
  }

  void onGameJustFinished() {}

  void loseRallyByServingTeam() {
    if (isGameFinished()) return;
    setState(() {
      pushScoreSnapshot();
      if (servingSide == ServeSide.left) {
        giveServeToRight();
      } else {
        giveServeToLeft();
      }
    });
  }

  bool _isGamePoint(int a, int b) {
    if ((a == targetScore - 1 && a > b) || (b == targetScore - 1 && b > a)) {
      return true;
    }
    if (useDeuce &&
        (a >= targetScore || b >= targetScore) &&
        (a - b).abs() == 1) {
      return true;
    }
    return false;
  }

  void _announceScore() {
    if (!_ttsEnabled) return;
    final a = scoreA;
    final b = scoreB;
    final t = s;

    if (isGameFinished()) {
      _speak(t.ttsGameOver(a, b));
      return;
    }

    if (useDeuce && a == b && a >= targetScore - 1) {
      _speak(t.ttsDeuce);
      return;
    }

    if (_isGamePoint(a, b)) {
      _speak(t.ttsGamePoint(a, b));
      return;
    }

    final cp = _courtChangePoint;
    final justReachedCP = (a == cp || b == cp);
    if (justReachedCP &&
        !_courtChangeAnnounced &&
        a < targetScore &&
        b < targetScore) {
      _courtChangeAnnounced = true;
      _speak(t.ttsCourtChangeWithScore(a, b));
      return;
    }

    _speak(t.ttsScore(a, b));
  }

  void changeCourt() {
    setState(() {
      pushScoreSnapshot();
      final tempL1 = leftPlayer1;
      final tempL2 = leftPlayer2;
      leftPlayer1 = rightPlayer1;
      leftPlayer2 = rightPlayer2;
      rightPlayer1 = tempL1;
      rightPlayer2 = tempL2;

      final tempScore = scoreA;
      scoreA = scoreB;
      scoreB = tempScore;

      final tempCurrent = leftCurrentServerIndex;
      leftCurrentServerIndex = rightCurrentServerIndex;
      rightCurrentServerIndex = tempCurrent;

      final tempLast = leftLastServerIndex;
      leftLastServerIndex = rightLastServerIndex;
      rightLastServerIndex = tempLast;

      final tempInitial = leftInitialServerIndex;
      leftInitialServerIndex = rightInitialServerIndex;
      rightInitialServerIndex = tempInitial;

      final tempHasServed = leftHasServed;
      leftHasServed = rightHasServed;
      rightHasServed = tempHasServed;

      servingSide =
          servingSide == ServeSide.left ? ServeSide.right : ServeSide.left;
    });
    _speak(s.ttsCourtChange);
  }

  void applyServeSetup(ServeSetupResult result) {
    final firstIsLeft = isLeftTeamGlobalIndex(result.firstServerGlobalIndex);
    final leftInitial = firstIsLeft
        ? toLocalIndex(result.firstServerGlobalIndex)
        : toLocalIndex(result.opponentFirstServerGlobalIndex);
    final rightInitial = firstIsLeft
        ? toLocalIndex(result.opponentFirstServerGlobalIndex)
        : toLocalIndex(result.firstServerGlobalIndex);
    setState(() {
      leftInitialServerIndex = leftInitial;
      rightInitialServerIndex = rightInitial;
      leftCurrentServerIndex = leftInitialServerIndex;
      rightCurrentServerIndex = rightInitialServerIndex;
      leftLastServerIndex = leftInitialServerIndex;
      rightLastServerIndex = rightInitialServerIndex;
      servingSide = firstIsLeft ? ServeSide.left : ServeSide.right;
      leftHasServed = firstIsLeft;
      rightHasServed = !firstIsLeft;
    });
  }

  Future<void> openBulkPlayerEditPage() async {
    final result = await Navigator.push<BulkPlayerEditResult>(
      context,
      MaterialPageRoute(
          builder: (_) => BulkPlayerEditPage(
                leftPlayer1: leftPlayer1,
                leftPlayer2: leftPlayer2,
                rightPlayer1: rightPlayer1,
                rightPlayer2: rightPlayer2,
              )),
    );
    if (!mounted || result == null) return;
    setState(() {
      leftPlayer1 =
          result.leftPlayer1.trim().isEmpty ? '선수1' : result.leftPlayer1.trim();
      leftPlayer2 =
          result.leftPlayer2.trim().isEmpty ? '선수2' : result.leftPlayer2.trim();
      rightPlayer1 = result.rightPlayer1.trim().isEmpty
          ? '선수3'
          : result.rightPlayer1.trim();
      rightPlayer2 = result.rightPlayer2.trim().isEmpty
          ? '선수4'
          : result.rightPlayer2.trim();
    });
  }
}

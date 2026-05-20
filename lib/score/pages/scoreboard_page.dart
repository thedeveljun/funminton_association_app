import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:badminton_association/score/enums/serve_side.dart';
import 'package:badminton_association/score/models/result_models.dart';
import 'package:badminton_association/score/models/saved_match_record.dart';
import 'package:badminton_association/score/pages/scoreboard_state.dart';
import 'package:badminton_association/score/pages/settings_page.dart';
import 'package:badminton_association/score/utils/share_match.dart';
import 'package:badminton_association/score/widgets/common_buttons.dart';
import 'package:badminton_association/score/widgets/player_header_widget.dart';
import 'package:badminton_association/score/widgets/score_board_widget.dart';
import 'package:badminton_association/services/orientation_service.dart';
import 'package:badminton_association/widgets/signature_pad.dart';

class ScoreboardPage extends StatefulWidget {
  /// 점수판 진입 시 자동 채울 좌측 페어 선수 2명.
  final String? initialLeftPlayer1;
  final String? initialLeftPlayer2;

  /// 점수판 진입 시 자동 채울 우측 페어 선수 2명.
  final String? initialRightPlayer1;
  final String? initialRightPlayer2;

  /// 컨텍스트 라벨. 예) "혼복 20-A조 · 1코트 1경기".
  /// null 이면 컨텍스트 띠 미노출 (친선 게임 모드).
  final String? contextLabel;

  const ScoreboardPage({
    super.key,
    this.initialLeftPlayer1,
    this.initialLeftPlayer2,
    this.initialRightPlayer1,
    this.initialRightPlayer2,
    this.contextLabel,
  });

  @override
  // ignore: no_logic_in_create_state
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends ScoreboardState<ScoreboardPage> {
  @override
  String get matchContextLabel => widget.contextLabel ?? '';

  /// 회전이 실제로 landscape 로 정착했음을 확인했는가.
  /// 진입 직후 잠시 portrait constraints 로 그려지면 점수판이 화면 절반만 차지하는
  /// 깨진 상태가 됨 — 이 플래그가 false 인 동안은 검은 로딩 화면만 렌더.
  bool _ready = false;

  // ── 전체화면 + 가로 방향 잠금 ─────────────────────────────────
  // 통합 앱에서 진입할 때 가로로 회전, 빠져나갈 때 세로로 복원.
  void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Native Activity-level lock — SystemChrome hint 만으론 OS sensor 가 묻을 수
    // 있어 transient race 발생. requestedOrientation 으로 OS 강제.
    OrientationService.lockLandscape();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Native lock 으로 portrait 강제 — 폰을 가로로 들고 있어도 OS 가 portrait 회전.
    OrientationService.lockPortrait();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  /// 디바이스 물리 크기가 landscape (width > height) 가 될 때까지 50ms 간격 폴링.
  /// 도착하면 + 200ms 후 _ready=true. 최대 2초 후 강제 진입.
  Future<void> _waitForLandscapeReady() async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < const Duration(seconds: 2)) {
      if (!mounted) return;
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final s = view.physicalSize;
      if (s.width > s.height) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (mounted) setState(() => _ready = true);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void initState() {
    super.initState();
    _enterFullscreen();
    initScoreboard(
      initialLeftPlayer1: widget.initialLeftPlayer1,
      initialLeftPlayer2: widget.initialLeftPlayer2,
      initialRightPlayer1: widget.initialRightPlayer1,
      initialRightPlayer2: widget.initialRightPlayer2,
    );
    _waitForLandscapeReady();
  }

  @override
  void dispose() {
    // disposeScoreboard 가 4방향 허용으로 덮어쓰므로 _exitFullscreen 을 뒤에 호출
    // → 최종적으로 세로 고정 유지.
    disposeScoreboard();
    _exitFullscreen();
    super.dispose();
  }

  // ── 게임 종료 직후: landscape 다이얼로그 → 회전 완료 폴링 → pop ──
  // 다이얼로그는 원본 landscape 점수판 위에 노출(정상 레이아웃).
  // 사용자 확인 후 portrait 회전을 요청하고, 실제 회전이 완료될 때까지 폴링하여
  // bracket_app 이 portrait 크기로 그려지도록 보장.
  @override
  void onGameJustFinished() {
    if (!mounted) return;
    _showGameEndCard();
  }

  /// 디바이스가 portrait 으로 회전 완료될 때까지 최대 2초 폴링.
  Future<void> _waitForPortrait() async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < const Duration(seconds: 2)) {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final s = view.physicalSize;
      if (s.height > s.width) return;
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// 팀 라벨 (선수 2명 이름) — 서명 다이얼로그 표시용.
  String _teamLabel(String? p1, String? p2) {
    final parts = [
      if ((p1 ?? '').isNotEmpty) p1!,
      if ((p2 ?? '').isNotEmpty) p2!,
    ];
    return parts.isEmpty ? '' : parts.join(' · ');
  }

  /// 게임 종료 시 호출 — 자동 저장 + **점수판 landscape 안에서 직접 서명 받음** +
  /// portrait 회전 + BracketScreen 으로 pop.
  ///
  /// 옛 흐름은 BracketScreen 복귀 직후 서명 다이얼로그 자동 호출 — 그 시점이
  /// portrait 회전 transient 와 겹쳐 RenderFlex overflow / freeze race 의 진원지.
  /// 본 흐름은 서명까지 점수판 안에서 끝내고 (회전 시작 전), 그 뒤에 단순 pop 만 하므로
  /// 회전 도중 어떤 dialog 도 띄워지지 않아 race 자체가 발생 불가.
  Future<void> _showGameEndCard() async {
    final navigator = Navigator.of(context);
    // 자동 저장 (옛 "저장하시겠습니까?" 확인 단계 생략 — 게임 종료 = 저장).
    if (canSaveMatch) {
      try {
        await saveCurrentMatch('none');
      } catch (_) {}
    }
    if (!mounted) return;

    // 점수판 안 (landscape) 에서 서명 다이얼로그 직접 호출. SingleChildScrollView
    // 안전망 보유 — 안정된 landscape 상에서 overflow 불가.
    String winnerSig = '';
    String winnerSide = '';
    try {
      final sigResult = await showWinnerSignatureDialog(
        context,
        scoreA: scoreA,
        scoreB: scoreB,
        teamALabel: _teamLabel(leftPlayer1, leftPlayer2),
        teamBLabel: _teamLabel(rightPlayer1, rightPlayer2),
      );
      if (sigResult != null) {
        winnerSig = sigResult.signature;
        winnerSide = sigResult.winnerSide;
      }
    } catch (_) {}
    if (!mounted) return;

    final result = <String, dynamic>{
      'scoreA': scoreA,
      'scoreB': scoreB,
      'leftPlayer1': leftPlayer1,
      'leftPlayer2': leftPlayer2,
      'rightPlayer1': rightPlayer1,
      'rightPlayer2': rightPlayer2,
      'winnerSignature': winnerSig,
      'winnerSide': winnerSide,
      // autoOpenSignature 제거 — 서명은 이미 점수판 안에서 받았음. race 진원지 차단.
    };
    // 회전 시작 → 실제 portrait 진입까지 대기 → 추가 settle delay → pop.
    try {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await _waitForPortrait();
      await Future.delayed(const Duration(milliseconds: 250));
    } catch (_) {}
    if (!mounted) return;
    debugPrint(
        '[ScBoard] popping with result keys=${result.keys.toList()} sA=$scoreA sB=$scoreB sigLen=${winnerSig.length}');
    try {
      navigator.pop(result);
    } catch (e) {
      debugPrint('[ScBoard] pop FAILED: $e');
    }
  }

  SavedMatchRecord _currentMatchRecord() {
    return SavedMatchRecord(
      savedAt: DateTime.now().toIso8601String(),
      leftPlayer1: leftPlayer1,
      leftPlayer2: leftPlayer2,
      rightPlayer1: rightPlayer1,
      rightPlayer2: rightPlayer2,
      scoreA: scoreA,
      scoreB: scoreB,
      targetScore: targetScore,
      useDeuce: useDeuce,
      myTeamSide: 'none',
      contextLabel: widget.contextLabel ?? '',
    );
  }

  Future<void> _onShareTapped() async {
    await ShareMatch.share(
      context: context,
      record: _currentMatchRecord(),
      s: s,
    );
  }

  // ── 저장 (팀 선택 단계 생략, 바로 기록저장) ────────────────────
  Future<void> _onSaveTapped() async {
    if (!saveEnabled) {
      final msg = !canSaveMatch
          ? s.needTwoPlayers
          : s.needMinScore(saveScoreThreshold);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
      return;
    }
    await saveCurrentMatch('none');
  }

  Widget _myTeamOption({
    required BuildContext ctx,
    required String side,
    required String label,
    required int score,
    required bool isWin,
  }) {
    final bg = isWin
        ? const Color(0xFF1565C0).withValues(alpha: 0.08)
        : const Color(0xFFD32F2F).withValues(alpha: 0.08);
    final border = isWin ? const Color(0xFF1565C0) : const Color(0xFFD32F2F);
    final isLoss = score < (side == 'left' ? scoreB : scoreA);
    final resultText = isWin ? s.win : (isLoss ? s.loss : s.draw);
    final resultColor = isWin
        ? const Color(0xFF1565C0)
        : (isLoss ? const Color(0xFFD32F2F) : Colors.grey);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.pop(ctx, side),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 1.5)),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          Text(s.points(score),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(7)),
            child: Text(resultText,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: resultColor)),
          ),
        ]),
      ),
    );
  }

  // ── 바텀시트 ───────────────────────────────────────────────────
  Future<T?> _showResponsiveBottomSheet<T>({
    required Widget child,
    double maxWidthFactor = 0.72,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (sheetCtx) {
        return LayoutBuilder(builder: (ctx, constraints) {
          final maxH = constraints.maxHeight * 0.9;
          final maxW = constraints.maxWidth * maxWidthFactor;
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        child: child),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _openServeSetupSheet() async {
    int? tempFirst;
    int? tempOpponent;
    if (leftHasServed || rightHasServed) {
      tempFirst = servingSide == ServeSide.left
          ? leftCurrentServerIndex
          : rightCurrentServerIndex + 2;
      tempOpponent = servingSide == ServeSide.left
          ? rightInitialServerIndex + 2
          : leftInitialServerIndex;
    }
    final result = await _showResponsiveBottomSheet<ServeSetupResult>(
      maxWidthFactor: 0.72,
      child: StatefulBuilder(builder: (ctx, setLocal) {
        final opponents =
            tempFirst == null ? <int>[] : opponentCandidatesOf(tempFirst!);
        final opponentValid =
            tempOpponent != null && opponents.contains(tempOpponent);
        final canConfirm = tempFirst != null && opponentValid;
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.firstServer,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _buildServeSelectionRow(
                  selectedGlobalIndex: tempFirst,
                  selectableIndexes: const [0, 1, 2, 3],
                  onSelect: (i) => setLocal(() {
                        tempFirst = i;
                        tempOpponent = null;
                      })),
              const SizedBox(height: 16),
              Text(s.opponentFirstServer,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _buildServeSelectionRow(
                  selectedGlobalIndex: tempOpponent,
                  selectableIndexes: opponents,
                  onSelect: (i) => setLocal(() => tempOpponent = i)),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s.close)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canConfirm
                      ? () => Navigator.pop(
                          ctx,
                          ServeSetupResult(
                              firstServerGlobalIndex: tempFirst!,
                              opponentFirstServerGlobalIndex: tempOpponent!))
                      : null,
                  child: Text(s.confirm),
                ),
              ]),
            ]);
      }),
    );
    if (!mounted || result == null) return;
    applyServeSetup(result);
  }

  Future<void> _openTargetScoreSheet() async {
    int tempTarget = targetScore;
    bool tempUseDeuce = useDeuce;
    final result = await _showResponsiveBottomSheet<Map<String, dynamic>>(
      maxWidthFactor: 0.55,
      child: StatefulBuilder(builder: (ctx, setLocal) {
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.targetScoreTitle,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: ScoreOptionButton(
                        label: s.points(15),
                        selected: tempTarget == 15,
                        onTap: () => setLocal(() => tempTarget = 15))),
                const SizedBox(width: 10),
                Expanded(
                    child: ScoreOptionButton(
                        label: s.points(21),
                        selected: tempTarget == 21,
                        onTap: () => setLocal(() => tempTarget = 21))),
                const SizedBox(width: 10),
                Expanded(
                    child: ScoreOptionButton(
                        label: s.points(25),
                        selected: tempTarget == 25,
                        onTap: () => setLocal(() => tempTarget = 25))),
              ]),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(s.deuceLabel,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text(s.deuceDescription,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black54)),
                      ])),
                  Switch(
                      value: tempUseDeuce,
                      onChanged: (v) => setLocal(() => tempUseDeuce = v)),
                ]),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s.cancel)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'targetScore': tempTarget,
                    'useDeuce': tempUseDeuce,
                  }),
                  child: Text(s.confirm),
                ),
              ]),
            ]);
      }),
    );
    if (!mounted || result == null) return;
    setState(() {
      targetScore = result['targetScore'] as int;
      useDeuce = result['useDeuce'] as bool;
    });
  }

  // ── 다이얼로그 ─────────────────────────────────────────────────
  void _showResetConfirmDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(s.resetTitle),
              content: Text(s.resetMessage),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s.cancel)),
                FilledButton(
                    onPressed: () {
                      resetScores();
                      Navigator.pop(ctx);
                    },
                    child: Text(s.confirm)),
              ],
            ));
  }

  void _showGameEndDialog() {
    // async 갭 전에 Navigator 참조 캐싱 — dispose 중 context 무효화 방지.
    final navigator = Navigator.of(context);
    showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(s.exitTitle),
              content: Text(s.exitMessage),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(s.cancel)),
                FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // 호출자(bracket_screen) 가 점수를 받아 Firestore 에 기록할 수
                      // 있도록 score+player 결과 페이로드와 함께 pop.
                      // (이전 maybePop 은 결과 없음 → Firestore 저장 누락 버그 원인.)
                      if (!mounted) return;
                      final result = <String, dynamic>{
                        'scoreA': scoreA,
                        'scoreB': scoreB,
                        'leftPlayer1': leftPlayer1,
                        'leftPlayer2': leftPlayer2,
                        'rightPlayer1': rightPlayer1,
                        'rightPlayer2': rightPlayer2,
                      };
                      try {
                        navigator.pop(result);
                      } catch (_) {}
                    },
                    child: Text(s.confirm)),
              ],
            ));
  }

  Future<void> _openSettingsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (mounted) {
      _enterFullscreen();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  // ── 서브 선택 행 ───────────────────────────────────────────────
  Widget _buildServeSelectionRow({
    required int? selectedGlobalIndex,
    required List<int> selectableIndexes,
    required ValueChanged<int> onSelect,
  }) {
    Widget box(int index) {
      final selected = selectedGlobalIndex == index;
      final enabled = selectableIndexes.contains(index);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => onSelect(index) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 48,
              decoration: BoxDecoration(
                color: !enabled
                    ? const Color(0xFFE6E6E6)
                    : selected
                        ? const Color(0xFF68A0F0)
                        : const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected ? const Color(0xFF3E76C9) : Colors.black12,
                    width: selected ? 1.4 : 1.0),
              ),
              child: Center(
                  child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(allPlayers[index],
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: !enabled
                              ? Colors.black38
                              : selected
                                  ? Colors.white
                                  : Colors.black87)),
                ),
              )),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      box(0),
      box(1),
      const SizedBox(
          width: 26,
          child: Center(
              child: Text('vs',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54)))),
      box(2),
      box(3),
    ]);
  }

  // ── 팀 컬럼 ────────────────────────────────────────────────────
  Widget _buildTeamColumn({
    required String player1,
    required String player2,
    required bool player1Serving,
    required bool player2Serving,
    required int score,
    required bool isServingTeam,
    required VoidCallback onScoreTap,
  }) {
    return Column(children: [
      PlayerHeaderWidget(
          player1: s.localizedPlayerName(player1),
          player2: s.localizedPlayerName(player2),
          player1Serving: player1Serving,
          player2Serving: player2Serving,
          onEditTeam: openBulkPlayerEditPage),
      const SizedBox(height: 4),
      Expanded(
          child: ScoreBoardWidget(
              score: score,
              isServingTeam: isServingTeam,
              targetScore: targetScore,
              onTap: onScoreTap,
              onLongPress: loseRallyByServingTeam)),
    ]);
  }

  // ── 가운데 컬럼 ────────────────────────────────────────────────
  Widget _buildCenterColumn() {
    return Column(children: [
      Expanded(flex: 4, child: _buildScoreCard()),
      const SizedBox(height: 4),
      Expanded(flex: 3, child: _buildCourtChangeButton()),
      const SizedBox(height: 4),
      CenterFixedButton(
          text: s.undo,
          backgroundColor: const Color.fromARGB(255, 81, 136, 255),
          borderColor: Colors.transparent,
          textColor: Colors.black,
          onTap: undoLastScore),
    ]);
  }

  Widget _buildScoreCard() {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: const Color(0xFFB39DDB),
        borderRadius: BorderRadius.circular(16),
        elevation: 12,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openTargetScoreSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(s.score,
                          style: const TextStyle(
                              color: Color(0xFF311B92),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1)))),
              const SizedBox(height: 10),
              Flexible(
                  flex: 2,
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('$targetScore',
                          style: const TextStyle(
                              color: Color(0xFF1A0954),
                              fontSize: 48,
                              fontWeight: FontWeight.w600,
                              height: 0.8)))),
              const SizedBox(height: 8),
              Flexible(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(deuceLabel,
                          style: const TextStyle(
                              color: Color(0xFF311B92),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              height: 1)))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCourtChangeButton() {
    return LayoutBuilder(builder: (context, constraints) {
      final double cw = constraints.maxWidth;
      final double iconSize = (cw * 0.18).clamp(12.0, 22.0);
      final double lineW = (cw * 0.35).clamp(24.0, 44.0);

      return SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: changeCourt,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF0F3460),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F3460).withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.4),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_rounded,
                            color: const Color(0xFF4FC3F7), size: iconSize),
                        SizedBox(width: cw * 0.03),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: lineW,
                              height: 2.5,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4FC3F7),
                                    Color(0xFF81D4FA)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: lineW,
                              height: 2.5,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF81D4FA),
                                    Color(0xFF4FC3F7)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: cw * 0.03),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: const Color(0xFF4FC3F7), size: iconSize),
                      ],
                    ),
                    SizedBox(height: cw * 0.04),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'CHANGE',
                        style: TextStyle(
                          color: const Color(0xFF4FC3F7),
                          fontSize: (cw * 0.11).clamp(9.0, 14.0),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  // ── TTS 버튼 (소리 on/off) ─────────────────────────────────────
  Widget _buildTtsButton({required double size}) {
    return GestureDetector(
      onTap: () => setState(() => toggleTts()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ttsEnabled ? const Color(0xFFFFD700) : Colors.white24,
            width: 1.4,
          ),
        ),
        child: Icon(
          ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          color: ttsEnabled ? const Color(0xFFFFD700) : Colors.white38,
          size: (size * 0.5).clamp(14.0, 24.0),
        ),
      ),
    );
  }

  // ── 설정 버튼 (언어 등) ────────────────────────────────────────
  Widget _buildSettingsButton({required double size}) {
    return GestureDetector(
      onTap: _openSettingsPage,
      child: Container(
        width: size,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1.4),
        ),
        child: Icon(
          Icons.language_rounded,
          color: Colors.white70,
          size: (size * 0.5).clamp(14.0, 24.0),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  Widget _loadingScaffold() => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white24,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(height: 16),
              const Text('가로 모드 전환 중…',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
        ),
      );

  Widget build(BuildContext context) {
    // 1) 물리 회전 완료 대기 (_ready 가 true 가 될 때까지).
    if (!_ready) return _loadingScaffold();
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 6),
        child: LayoutBuilder(builder: (context, constraints) {
        // 2) LayoutBuilder constraints + 폰의 물리 size 둘 다 확인.
        //    Scaffold/SafeArea 가 첫 프레임에 stale insets 줄 수 있고, 회전 잠금이
        //    켜진 폰은 OS 가 landscape 강제를 거부하지만 LayoutBuilder constraints
        //    는 transitional 로 landscape 비율 받기도 한다. 둘 다 체크해서 안내 노출.
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final phys = view.physicalSize;
        final isRealLandscape = phys.width > phys.height;
        if (!isRealLandscape || constraints.maxWidth <= constraints.maxHeight) {
          // 폰의 자동 회전이 잠겨 있어 landscape 강제가 안 되는 케이스.
          // 무한 스피너 (검은 화면처럼 보임) 대신 친절한 안내 + 닫기 버튼.
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_rotation,
                      size: 64, color: Colors.white70),
                  const SizedBox(height: 20),
                  const Text('점수판은 가로 모드 전용입니다',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  const Text(
                    '폰을 가로로 돌리거나\n시스템 설정 → 자동 회전을 켜주세요.',
                    style: TextStyle(
                        color: Colors.white60, fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('돌아가기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final double sw = constraints.maxWidth;
        final double sh = constraints.maxHeight;

        final double hPad = sw * 0.004;
        final double centerWidth = (sw * 0.111).clamp(66.0, 102.0);
        final double centerGap = (sw * 0.012).clamp(6.0, 16.0);
        final double scoreGap = (sh * 0.015).clamp(4.0, 10.0);
        final double bottomRowH = (sh * 0.12).clamp(32.0, 50.0);

        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 2, hPad, 2),
          child: Column(children: [
            // ── 점수판 영역 ──────────────────────────────────────
            Expanded(
              child: Row(children: [
                Expanded(
                    child: _buildTeamColumn(
                  player1: leftPlayer1,
                  player2: leftPlayer2,
                  player1Serving: isLeftPlayer1Serving,
                  player2Serving: isLeftPlayer2Serving,
                  score: scoreA,
                  isServingTeam: servingSide == ServeSide.left,
                  onScoreTap: addScoreA,
                )),
                SizedBox(width: centerGap),
                SizedBox(width: centerWidth, child: _buildCenterColumn()),
                SizedBox(width: centerGap),
                Expanded(
                    child: _buildTeamColumn(
                  player1: rightPlayer1,
                  player2: rightPlayer2,
                  player1Serving: isRightPlayer1Serving,
                  player2Serving: isRightPlayer2Serving,
                  score: scoreB,
                  isServingTeam: servingSide == ServeSide.right,
                  onScoreTap: addScoreB,
                )),
              ]),
            ),

            SizedBox(height: scoreGap),

            // ── 하단 버튼 영역 ───────────────────────────────────
            SizedBox(
              height: bottomRowH,
              child: Row(children: [
                // 왼쪽: 🌐 다국어(끝) + 서브선택 + 점수리셋
                Expanded(
                    child: Row(children: [
                  Flexible(child: _buildSettingsButton(size: sw * 0.072)),
                  SizedBox(width: sw * 0.008),
                  Flexible(
                    child: SizedBox(
                      width: sw * 0.135,
                      child: BottomTextButton(
                        text: s.chooseServe,
                        textColor: Colors.white,
                        backgroundColor: Colors.black,
                        borderColor: Colors.white,
                        onTap: _openServeSetupSheet,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: SizedBox(
                      width: sw * 0.135,
                      child: BottomTextButton(
                        text: s.reset,
                        textColor: const Color(0xFF00E5FF),
                        backgroundColor: Colors.black,
                        borderColor: Colors.white,
                        onTap: _showResetConfirmDialog,
                      ),
                    ),
                  ),
                ])),

                SizedBox(width: centerGap),
                SizedBox(width: centerWidth),
                SizedBox(width: centerGap),

                // 오른쪽: 게임종료 + 기록저장 + 🔊 TTS(끝)
                Expanded(
                    child: Row(children: [
                  Flexible(
                    child: SizedBox(
                      width: sw * 0.135,
                      child: BottomTextButton(
                        text: s.exitGame,
                        textColor: const Color(0xFFFF79C6),
                        backgroundColor: Colors.black,
                        borderColor: Colors.white,
                        onTap: _showGameEndDialog,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: SizedBox(
                      width: sw * 0.135,
                      child: BottomTextButton(
                        text: s.saveRecord,
                        textColor: saveEnabled ? Colors.white : Colors.white38,
                        backgroundColor: Colors.black,
                        borderColor: saveEnabled ? Colors.white : Colors.white24,
                        onTap: saveEnabled ? _onSaveTapped : null,
                        onLongPress: openSavedMatchesPage,
                      ),
                    ),
                  ),
                  SizedBox(width: sw * 0.008),
                  Flexible(child: _buildTtsButton(size: sw * 0.072)),
                ])),
              ]),
            ),
          ]),
        );
      }),
      ),
    );
  }
}

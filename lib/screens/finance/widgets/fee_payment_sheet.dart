// lib/screens/finance/widgets/fee_payment_sheet.dart
//
// 협회비 선수별 납부 체크 시트.
// 클럽 카드 탭 시 하단에서 올라오는 BottomSheet.
//
// 기능:
//   - 클럽 소속 선수 가나다순 표시
//   - 선수 검색 (이름/급수/전화번호)
//   - 미납자 체크박스 다중 선택
//   - 전체 선택 / 일괄 납부 처리
//   - 납부 완료 행 길게 누름 → 납부 취소
//   - 클럽 통계 박스 (납부 인원 / 납부 금액)
//
// 호출 예:
//   showModalBottomSheet(
//     context: context,
//     builder: (_) => FeePaymentSheet(
//       club: club,
//       onPay: _addFeePayment,
//       onCancel: _removeFeePayment,
//     ),
//   );

import 'package:flutter/material.dart';

import '../../../core/constants/app_config.dart';
import '../../../models/club.dart';
import '../../../models/player.dart';
import '../../../models/player_fee_payment.dart';
import '../../../services/sample_data.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

class FeePaymentSheet extends StatefulWidget {
  final Club club;
  final void Function(Player) onPay;
  final void Function(Player) onCancel;

  const FeePaymentSheet({
    required this.club,
    required this.onPay,
    required this.onCancel,
  });

  @override
  State<FeePaymentSheet> createState() => _FeePaymentSheetState();
}

class _FeePaymentSheetState extends State<FeePaymentSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  /// 선택된 선수들의 ID Set (미납자 중에서만 선택 가능)
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 클럽 소속 선수 리스트 (이름 가나다순 정렬)
  List<Player> get _clubPlayers {
    final list =
        SampleData.players.where((p) => p.clubId == widget.club.id).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// 검색 필터링된 선수 리스트
  List<Player> get _filteredPlayers {
    if (_query.trim().isEmpty) return _clubPlayers;
    final q = _query.trim().toLowerCase();
    return _clubPlayers.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.gradeShort.toLowerCase().contains(q) ||
          p.phone.contains(q);
    }).toList();
  }

  /// 검색 결과 중 미납자 (선택 가능한 대상)
  List<Player> get _filteredUnpaid =>
      _filteredPlayers.where((p) => !_isPaid(p)).toList();

  /// 전체 선택 상태:
  /// - 검색 결과의 미납자 모두 선택됨 → true
  /// - 일부만 선택됨 → null (indeterminate)
  /// - 아무도 선택 안됨 → false
  bool? get _selectAllState {
    final unpaid = _filteredUnpaid;
    if (unpaid.isEmpty) return false;
    final selectedInView =
        unpaid.where((p) => _selectedIds.contains(p.id)).length;
    if (selectedInView == 0) return false;
    if (selectedInView == unpaid.length) return true;
    return null; // 일부 선택
  }

  /// 특정 선수의 올해 납부 여부
  bool _isPaid(Player player) {
    final yr = DateTime.now().year;
    return SampleData.playerFeePayments
        .any((p) => p.playerId == player.id && p.year == yr);
  }

  /// 클럽 전체 납부 현황 집계
  ClubFeeSummary get _summary {
    final players = _clubPlayers;
    return ClubFeeSummary.from(
      clubId: widget.club.id,
      clubName: widget.club.name,
      totalPlayers: players.length,
      allPayments: SampleData.playerFeePayments,
    );
  }

  /// 미납 선수 행 탭 → 선택 토글
  void _toggleSelection(Player player) {
    if (_isPaid(player)) return; // 이미 납부된 선수는 토글 안함
    setState(() {
      if (_selectedIds.contains(player.id)) {
        _selectedIds.remove(player.id);
      } else {
        _selectedIds.add(player.id);
      }
    });
  }

  /// 전체 선택/해제 (검색 결과의 미납자 대상)
  void _toggleSelectAll() {
    final unpaid = _filteredUnpaid;
    if (unpaid.isEmpty) return;
    setState(() {
      final state = _selectAllState;
      if (state == true) {
        // 전체 해제 (검색 결과의 미납자만)
        for (final p in unpaid) {
          _selectedIds.remove(p.id);
        }
      } else {
        // 전체 선택 (검색 결과의 미납자만)
        for (final p in unpaid) {
          _selectedIds.add(p.id);
        }
      }
    });
  }

  /// 선택 전체 해제 (검색 무관, 모두 해제)
  void _clearAllSelection() {
    setState(() => _selectedIds.clear());
  }

  /// 이미 납부된 선수 길게 눌러서 → 납부 취소
  Future<void> _onLongPressPaidPlayer(Player player) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('납부 취소',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${player.name} (${player.gradeShort}조)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '납부를 취소하시겠습니까?\n(연결된 수입 거래도 함께 삭제됩니다)',
              style: TextStyle(fontSize: 13, color: kInk),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('아니오', style: TextStyle(color: Color(0xFF555555))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소하기',
                style:
                    TextStyle(color: kExpenseFg, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.onCancel(player);
      if (mounted) setState(() {});
    }
  }

  /// 선택된 선수들 일괄 납부 처리
  Future<void> _payAllSelected() async {
    final selectedPlayers =
        _clubPlayers.where((p) => _selectedIds.contains(p.id)).toList();
    if (selectedPlayers.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('일괄 납부',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          '선택된 선수 ${selectedPlayers.length}명을 납부 처리하시겠습니까?\n'
          '총 ${fmtAmt(selectedPlayers.length * AppConfig.playerFeeUnit)}',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Color(0xFF555555))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('납부 처리',
                style: TextStyle(color: kAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      for (final p in selectedPlayers) {
        widget.onPay(p);
      }
      if (mounted) {
        setState(() => _selectedIds.clear());
        // 납부 처리 완료 후 시트 자동 닫기
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final filtered = _filteredPlayers;
    final selectAll = _selectAllState;
    final selectedCount = _selectedIds.length;
    final selectedAmount = selectedCount * AppConfig.playerFeeUnit;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 핸들
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E4EC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── 헤더 (납부인원 + 납부금액) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.club.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kInk,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kBannerNavy, kBannerNavyAlt],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '납부 인원',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.75),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${s.paidPlayers}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: kAmountYellow,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${s.totalPlayers}명',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.85),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withOpacity(0.18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '납부 금액',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.75),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                fmtAmt(s.totalPaid),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),

            // ── 전체 선택 바 ⭐ NEW ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: InkWell(
                onTap: _toggleSelectAll,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFFD5DAE1), width: 1),
                  ),
                  child: Row(children: [
                    // 전체 선택 체크박스 (3-state)
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selectAll == true
                            ? kAccent
                            : (selectAll == null
                                ? kAccent.withOpacity(0.3)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: selectAll == false
                              ? const Color(0xFFB8BEC9)
                              : kAccent,
                          width: 1.6,
                        ),
                      ),
                      child: selectAll == true
                          ? const Icon(Icons.check,
                              size: 15, color: Colors.white)
                          : selectAll == null
                              ? const Icon(Icons.remove,
                                  size: 15, color: Colors.white)
                              : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '전체 선택',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selectAll == false
                            ? const Color(0xFF555555)
                            : kAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(미납자 ${_filteredUnpaid.length}명)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF555555),
                      ),
                    ),
                    const Spacer(),
                    if (selectedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: kAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$selectedCount명 선택',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),

            // ── 검색창 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 15, height: 1.0),
                  decoration: InputDecoration(
                    hintText: '선수 이름 검색',
                    hintStyle: const TextStyle(
                        fontSize: 14, color: Color(0xFFAAAAAA), height: 1.0),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Color(0xFF888888)),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.clear,
                                size: 18, color: Color(0xFF888888)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF5F6F8),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: kAccent, width: 1.4),
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: kCardBorderLight),

            // ── 선수 리스트 ──
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(children: [
                          const Icon(Icons.person_search_outlined,
                              size: 36, color: Color(0xFFCCCCCC)),
                          const SizedBox(height: 8),
                          Text(
                            _query.isEmpty ? '소속 선수가 없습니다' : '검색 결과가 없습니다',
                            style: const TextStyle(fontSize: 13, color: kMuted),
                          ),
                        ]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        final paid = _isPaid(p);
                        return _PlayerCheckTile(
                          player: p,
                          paid: paid,
                          selected: _selectedIds.contains(p.id),
                          unitFee: AppConfig.playerFeeUnit,
                          onTap: () => paid
                              ? _onLongPressPaidPlayer(p)
                              : _toggleSelection(p),
                          onLongPress:
                              paid ? () => _onLongPressPaidPlayer(p) : null,
                        );
                      },
                    ),
            ),

            const Divider(height: 1, color: kCardBorderLight),

            // ── 하단 액션 영역 ⭐ 변경 ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 10, 20, 10 + MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 선택 정보
                  if (selectedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '선택 ${selectedCount}명',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kInk,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            fmtAmt(selectedAmount),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: kIncomeFg,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 버튼들
                  Row(children: [
                    // 선택 해제 버튼 (선택된 게 있을 때만 활성)
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed:
                            selectedCount > 0 ? _clearAllSelection : null,
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('선택 해제'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: selectedCount > 0
                                  ? const Color(0xFFB6BCC8)
                                  : const Color(0xFFE0E4EC)),
                          foregroundColor: selectedCount > 0
                              ? const Color(0xFF555555)
                              : const Color(0xFFAAAAAA),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 납부 처리 버튼
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: selectedCount > 0 ? _payAllSelected : null,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(selectedCount > 0
                            ? '${selectedCount}명 납부 처리'
                            : '선수 선택 후 납부'),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: kAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE0E4EC),
                          disabledForegroundColor: const Color(0xFF888888),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 선수별 체크 행 (3가지 상태: 미납/선택중/납부완료)
class _PlayerCheckTile extends StatelessWidget {
  final Player player;
  final bool paid;
  final bool selected;
  final int unitFee;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PlayerCheckTile({
    required this.player,
    required this.paid,
    required this.selected,
    required this.unitFee,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // 3가지 상태 색상
    final Color tileBg;
    final Color checkBg;
    final Color checkBorder;
    final IconData? checkIcon;

    if (paid) {
      // 납부 완료: 연한 초록
      tileBg = const Color(0xFFF6FBF7);
      checkBg = kIncomeIcon;
      checkBorder = kIncomeIcon;
      checkIcon = Icons.check;
    } else if (selected) {
      // 선택 중: 연한 파랑
      tileBg = const Color(0xFFEFF5FB);
      checkBg = kAccent;
      checkBorder = kAccent;
      checkIcon = Icons.check;
    } else {
      // 미납: 흰색
      tileBg = Colors.transparent;
      checkBg = Colors.white;
      checkBorder = const Color(0xFFB8BEC9);
      checkIcon = null;
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        color: tileBg,
        child: Row(
          children: [
            // 체크박스
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: checkBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: checkBorder, width: 1.6),
              ),
              child: checkIcon != null
                  ? Icon(checkIcon, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            // 선수 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: paid ? const Color(0xFF555555) : kInk,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF1F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        player.gradeShort,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF555555),
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      player.gender,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 1),
                  Text(
                    player.regNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            // 우측 상태
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  paid ? '납부' : (selected ? '선택' : '미납'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: paid
                        ? kIncomeFg
                        : (selected ? kAccent : const Color(0xFF666666)),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  paid || selected
                      ? fmtAmt(unitFee).replaceAll('-', '')
                      : '${unitFee.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: paid
                        ? kIncomeFg
                        : (selected ? kAccent : const Color(0xFF555555)),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

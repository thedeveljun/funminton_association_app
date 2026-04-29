// lib/screens/finance/widgets/grouped_fee_row.dart
//
// 수입/지출 탭의 협회비 그룹 행 위젯.
// 같은 클럽이 같은 날(2분 이내)에 여러 명 납부한 경우 1줄로 묶어서 표시.
// 탭하면 명단 시트가 열려 누가 납부했는지 확인 가능.
//
// 포함 클래스:
//   - DisplayItem: 수입/지출 탭이 보여줄 한 줄을 나타내는 데이터 (단건 또는 그룹)
//   - GroupedFeeRow: 그룹을 카드 형태로 그리는 위젯

import 'package:flutter/material.dart';

import '../../../core/constants/app_config.dart';
import '../../../models/finance_transaction.dart';
import '../../../models/player.dart';
import '../../../services/sample_data.dart';
import 'finance_constants.dart';
import 'finance_helpers.dart';

class DisplayItem {
  final String date;
  final List<FinanceTransaction> sourceTransactions;
  final bool isGroup;

  // 그룹 전용
  final String? groupClubName;
  final int? groupTotal;
  final int? groupCount;

  DisplayItem._({
    required this.date,
    required this.sourceTransactions,
    required this.isGroup,
    this.groupClubName,
    this.groupTotal,
    this.groupCount,
  });

  factory DisplayItem.single(FinanceTransaction tx) => DisplayItem._(
        date: tx.date,
        sourceTransactions: [tx],
        isGroup: false,
      );

  factory DisplayItem.feeGroup(List<FinanceTransaction> txs) {
    final first = txs.first;
    final total = txs.fold<int>(0, (s, t) => s + t.amount);
    return DisplayItem._(
      date: first.date,
      sourceTransactions: txs,
      isGroup: true,
      groupClubName: first.clubName,
      groupTotal: total,
      groupCount: txs.length,
    );
  }
}

// ── 협회비 그룹 행 ──────────────────────────────
class GroupedFeeRow extends StatelessWidget {
  final DisplayItem item;
  const GroupedFeeRow({required this.item});

  /// 거래 title("중앙 배드민턴 클럽 - 강건우")에서 선수 이름만 추출.
  /// 과거 형식("... 협회비")도 호환 처리.
  String _extractPlayerName(FinanceTransaction tx) {
    final parts = tx.title.split(' - ');
    if (parts.length >= 2) {
      final last = parts.last;
      if (last.endsWith(' 협회비')) {
        return last.substring(0, last.length - ' 협회비'.length);
      }
      return last;
    }
    return tx.title;
  }

  /// ID 문자열에서 timestamp 추출 (정렬용, 접두사 무관)
  int _extractTimestamp(String id) {
    final match = RegExp(r'(\d{13,})').firstMatch(id);
    if (match == null) return 0;
    final raw = int.tryParse(match.group(1)!) ?? 0;
    return match.group(1)!.length >= 16 ? raw ~/ 1000 : raw;
  }

  /// 그룹 내 가장 최근 거래의 시간 추출 (timestamp 기반)
  String _groupLatestTime() {
    if (item.sourceTransactions.isEmpty) return '';
    // timestamp가 가장 큰 거래의 ID에서 시간 추출
    final latest = item.sourceTransactions.reduce(
        (a, b) => _extractTimestamp(a.id) > _extractTimestamp(b.id) ? a : b);
    return extractTimeFromId(latest.id);
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final txs = item.sourceTransactions;
        final names = txs.map(_extractPlayerName).toList()..sort();
        final maxHeight = MediaQuery.of(context).size.height * 0.7;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E4EC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.groupClubName ?? '',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kInk,
                          letterSpacing: -0.4,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      '${item.date} · ${item.groupCount}명 납부 · ${fmtAmt(item.groupTotal ?? 0)}',
                      style: const TextStyle(fontSize: 12, color: kMuted),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kCardBorderLight),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: names.length,
                  itemBuilder: (_, i) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF1F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF555555),
                            )),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(names[i],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kInk,
                              letterSpacing: -0.3,
                            )),
                      ),
                      Text(
                        '+${fmtAmt(AppConfig.playerFeeUnit).replaceAll('-', '')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kIncomeFg,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kIncomeBorder, width: 1.4),
          boxShadow: const [
            BoxShadow(
                color: Color(0x06000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kIncomeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.groups_rounded, size: 18, color: kIncomeIcon),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        item.groupClubName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kInk,
                          letterSpacing: -0.3,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${fmtAmt(item.groupTotal ?? 0).replaceAll('-', '')}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kIncomeFg,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Row(children: [
                  Text(item.date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        letterSpacing: -0.2,
                      )),
                  if (_groupLatestTime().isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(_groupLatestTime(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF888888),
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                  const Text(' · ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.groupCount}명 납부',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kIncomeFg,
                      ),
                    ),
                  ),
                ]),
                // 메모: "{년도}년 협회비" 노란 배지
                const SizedBox(height: 1),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sticky_note_2_outlined,
                          size: 11, color: Color(0xFFB7791F)),
                      const SizedBox(width: 3),
                      Text(
                        '${DateTime.now().year}년 협회비',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8B6914),
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.expand_more_rounded,
              size: 18, color: Color(0xFFAAAAAA)),
        ]),
      ),
    );
  }
}

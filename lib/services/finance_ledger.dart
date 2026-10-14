// lib/services/finance_ledger.dart
//
// 수입/지출 장부의 연동 규칙 — 펀클럽(funminton_club_app) 재정관리의
// 반납·되돌리기·연동 줄 잠금을 협회 자료(협회비·분담금·찬조)에 맞춰 옮겼다.
//
// ── 연동 표시(FinanceTransaction.link) ──
//   협회비_<키>      협회비 납부로 생긴 수입 (PlayerFeePayment.txId == 키)
//   분담금_<키>      분담금 납부로 생긴 수입 (ClubShare.txId == 키)
//   찬조_<키>        현금 찬조로 생긴 수입   (Donation.txId == 키)
//   협회비납부_<키> / 분담금납부_<키>   반납 처리가 끝난 받은 기록(수입)
//   협회비반납_<키> / 분담금반납_<키>   돌려준 기록(지출). restore 에 떼어 낸 납부 기록
// 키는 처음 생긴 수입 거래의 id 다.
//
// ── 규칙 ──
// - 연동 줄은 장부에서 고치지 않는다. 금액·이름은 원래 화면(협회비·대회재정)에서 고친다.
// - 협회비·분담금 줄을 지우면 '반납' 으로 적는다: 받은 기록은 남기고 같은 금액의
//   지출을 덧붙여 잔액만 맞춘다. 납부 기록은 미납으로 돌아간다.
// - 반납이 끝난 짝(받은 기록·돌려준 기록)은 지울 수 없다. 한쪽만 지우면 잔액이
//   어긋난다. 대신 '반납 되돌리기' 로 짝을 함께 걷어내고 낸 것으로 되돌린다.
// - 찬조 줄은 반납 짝 없이 지운다. 지우면 대회의 찬조 목록에서도 빠진다.

import '../models/club_share.dart';
import '../models/donation.dart';
import '../models/finance_transaction.dart';
import '../models/player_fee_payment.dart';
import 'finance_log.dart';
import 'sample_data.dart';
import 'storage_service.dart';

enum LedgerAction { delete, refund, locked, donation }

/// 납부를 푸는 까닭 / 납부한 것을 지울 때 고른 처리.
enum UnpayChoice { refunded, mistake, keep }

class FinanceLedger {
  FinanceLedger._();

  static const kinds = ['협회비', '분담금', '찬조'];

  static List<FinanceTransaction> get _txs => SampleData.transactions;

  // ── 태그 읽기 ─────────────────────────────

  static String? _kindOfTag(String? link, String suffix) {
    if (link == null) return null;
    for (final k in kinds) {
      if (link.startsWith('$k${suffix}_')) return k;
    }
    return null;
  }

  /// 살아 있는 연동 줄의 종류(협회비·분담금·찬조). 아니면 널.
  static String? liveKind(FinanceTransaction t) => _kindOfTag(t.link, '');

  static bool isLinkedLive(FinanceTransaction t) => liveKind(t) != null;

  /// 반납이 끝난 받은 기록
  static bool isSettledPaid(FinanceTransaction t) =>
      _kindOfTag(t.link, '납부') != null;

  /// 돌려준 기록
  static bool isRefund(FinanceTransaction t) =>
      _kindOfTag(t.link, '반납') != null;

  static bool isSettled(FinanceTransaction t) =>
      isSettledPaid(t) || isRefund(t);

  /// 태그의 키(처음 수입 거래 id)
  static String keyOf(String link) => link.substring(link.indexOf('_') + 1);

  static String? settledKind(FinanceTransaction t) =>
      _kindOfTag(t.link, '납부') ?? _kindOfTag(t.link, '반납');

  static LedgerAction actionOf(FinanceTransaction t) {
    if (isSettled(t)) return LedgerAction.locked;
    final k = liveKind(t);
    if (k == '찬조') return LedgerAction.donation;
    if (k != null) return LedgerAction.refund;
    return LedgerAction.delete;
  }

  static String titleOf(LedgerAction a, FinanceTransaction t) {
    switch (a) {
      case LedgerAction.refund:
        return '${liveKind(t)} 반납할까요?';
      case LedgerAction.locked:
        return '지울 수 없는 기록입니다';
      case LedgerAction.donation:
        return '찬조를 삭제할까요?';
      case LedgerAction.delete:
        return '삭제할까요?';
    }
  }

  static String confirmLabelOf(LedgerAction a) =>
      a == LedgerAction.refund ? '반납' : '삭제';

  static const String lockedReason = '이미 반납 처리가 끝난 기록입니다.\n'
      '받은 기록과 돌려준 기록이 짝이라, 한쪽만 고치거나 지우면 잔액이 어긋납니다.';

  /// 연동 줄이 어느 화면에서 왔는지.
  static String whereOf(String kind) =>
      kind == '협회비' ? '협회비' : '대회재정';

  // ── 반납 ───────────────────────────────

  /// 살아 있는 협회비·분담금 줄을 반납으로 처리한다.
  /// 받은 기록은 '납부' 로 굳히고 같은 금액의 지출을 덧붙인다. 납부 기록은 미납으로.
  static Future<void> refund(FinanceTransaction tx) async {
    final kind = liveKind(tx);
    if (kind == null || kind == '찬조') return;
    final key = keyOf(tx.link!);

    Map<String, dynamic>? restore;
    if (kind == '협회비') {
      final p = SampleData.playerFeePayments
          .where((p) => p.txId == key || p.txId == tx.id)
          .toList();
      if (p.isNotEmpty) restore = p.first.toMap();
      SampleData.playerFeePayments
          .removeWhere((p) => p.txId == key || p.txId == tx.id);
    } else {
      final i = SampleData.clubShares
          .indexWhere((s) => s.txId == key || s.txId == tx.id);
      if (i >= 0) {
        restore = SampleData.clubShares[i].toMap();
        SampleData.clubShares[i] = SampleData.clubShares[i].markUnpaid();
      }
    }

    _replace(tx.copyWith(link: '$kind납부_$key'));
    _txs.add(FinanceTransaction(
      id: 'tx_rf_${DateTime.now().microsecondsSinceEpoch}',
      title: tx.title,
      amount: tx.amount,
      isIncome: false,
      category: tx.category,
      date: _nowStr(),
      clubId: tx.clubId,
      clubName: tx.clubName,
      tournamentId: tx.tournamentId,
      tournamentName: tx.tournamentName,
      memo: '$kind 반납',
      link: '$kind반납_$key',
      restore: restore,
    ));

    await FinanceLog.add('$kind 반납', tx.title, '${_fmt(tx.amount)} 돌려줌');
    await _saveAll();
  }

  /// 짝을 찾는다. (받은 기록, 돌려준 기록)
  static (FinanceTransaction, FinanceTransaction)? pairOf(
      FinanceTransaction t) {
    final kind = settledKind(t);
    if (kind == null) return null;
    final key = keyOf(t.link!);
    final paid =
        _txs.where((x) => x.link == '$kind납부_$key').toList();
    final back =
        _txs.where((x) => x.link == '$kind반납_$key').toList();
    if (paid.isEmpty || back.isEmpty) return null;
    return (paid.first, back.first);
  }

  /// 되돌리기가 가능한지 — 짝이 있고, 그 사이 같은 대상이 다시 납부되지 않았는지.
  static String? undoBlocker(FinanceTransaction t) {
    final pair = pairOf(t);
    if (pair == null) return '짝이 되는 기록을 찾지 못했습니다.';
    final kind = settledKind(t)!;
    final r = pair.$2.restore;
    if (r == null) return null;
    if (kind == '협회비') {
      final p = PlayerFeePayment.fromMap(r);
      final again = SampleData.playerFeePayments
          .any((x) => x.playerId == p.playerId && x.year == p.year);
      if (again) return '${p.playerName} 선수의 ${p.year}년 협회비가 이미 다시 납부되어 있습니다.';
    } else {
      final s = ClubShare.fromMap(r);
      final cur = SampleData.clubShares.where((x) => x.id == s.id);
      if (cur.isNotEmpty && cur.first.paid) {
        return '${s.clubName} 분담금이 이미 다시 납부되어 있습니다.';
      }
    }
    return null;
  }

  static String undoLabelOf(FinanceTransaction t) =>
      '${settledKind(t) ?? ''} 반납 되돌리기';

  /// 반납을 되돌린다 — 돌려준 기록을 걷어내고 받은 기록을 다시 살아 있는 줄로,
  /// 납부 기록도 낸 것으로 되살린다. 성공하면 true.
  static Future<bool> undoRefund(FinanceTransaction t) async {
    if (undoBlocker(t) != null) return false;
    final (paid, back) = pairOf(t)!;
    final kind = settledKind(t)!;
    final key = keyOf(paid.link!);

    final r = back.restore;
    if (r != null) {
      if (kind == '협회비') {
        SampleData.playerFeePayments
            .add(PlayerFeePayment.fromMap(r).copyWith(txId: paid.id));
      } else {
        final s = ClubShare.fromMap(r);
        final i = SampleData.clubShares.indexWhere((x) => x.id == s.id);
        final restored = (i >= 0 ? SampleData.clubShares[i] : s).markPaid(
            paidDate: s.paidDate ?? _nowStr().substring(0, 10), txId: paid.id);
        if (i >= 0) {
          SampleData.clubShares[i] = restored;
        } else {
          SampleData.clubShares.add(restored);
        }
      }
    }

    _txs.removeWhere((x) => x.id == back.id);
    _replace(paid.copyWith(link: '${kind}_$key'));
    await FinanceLog.add(
        '$kind 반납 되돌림', paid.title, '${_fmt(paid.amount)} · 낸 것으로 되돌림');
    await _saveAll();
    return true;
  }

  // ── 지우기 ─────────────────────────────

  /// 손으로 적은 줄을 지운다.
  static Future<void> deletePlain(FinanceTransaction tx) async {
    _txs.removeWhere((x) => x.id == tx.id);
    await FinanceLog.add('${tx.isIncome ? '수입' : '지출'} 삭제', tx.title,
        '${_fmt(tx.amount)} · ${_fmtStamp(tx.date)}');
    await SampleData.saveTransactions();
  }

  /// 찬조 줄을 지운다 — 대회의 찬조 목록에서도 뺀다.
  static Future<void> deleteDonationRow(FinanceTransaction tx) async {
    final key = keyOf(tx.link!);
    _txs.removeWhere((x) => x.id == tx.id);
    SampleData.donations.removeWhere((d) => d.txId == key || d.txId == tx.id);
    await FinanceLog.add('찬조금 삭제', tx.title, _fmt(tx.amount));
    await SampleData.saveTransactions();
    await SampleData.saveDonations();
  }

  /// '잘못 눌렀어요' — 받은 기록을 장부에서 걷어낸다(반납 짝 없이).
  /// 납부 기록 자체는 부르는 쪽에서 지운다.
  static Future<void> dropLinkedTx(String? txId, String kind) async {
    if (txId == null) return;
    final t = _txs.where((x) => x.id == txId).toList();
    _txs.removeWhere((x) => x.id == txId);
    if (t.isNotEmpty) {
      await FinanceLog.add('$kind 입력 취소', t.first.title, _fmt(t.first.amount));
    }
  }

  /// '안 돌려줌' — 연동을 끊고 받은 돈을 보통 수입으로 남긴다.
  static Future<void> keepAsIncome(String? txId, String note) async {
    if (txId == null) return;
    final i = _txs.indexWhere((x) => x.id == txId);
    if (i < 0) return;
    final t = _txs[i];
    final kind = liveKind(t) ?? '';
    final memo = [if ((t.memo ?? '').isNotEmpty) t.memo!, '($note)'].join(' ');
    _txs[i] = t.copyWith(clearLink: true, memo: memo);
    await FinanceLog.add('$kind 수입으로 남김', t.title, _fmt(t.amount));
  }

  // ── 찬조 ↔ 장부 ─────────────────────────

  /// 찬조를 장부에 맞춘다. 현금 찬조(금액>0)는 수입 줄을 만들거나 고치고,
  /// 물품 찬조로 바뀌었거나 금액이 0이면 줄을 지운다. txId 를 맞춘 찬조를 돌려준다.
  static Donation syncDonation(Donation d) {
    final wantTx = d.kind == DonationKind.cash && d.amount > 0;
    final idx = d.txId == null ? -1 : _txs.indexWhere((t) => t.id == d.txId);
    if (!wantTx) {
      if (idx >= 0) _txs.removeAt(idx);
      return Donation.fromMap({...d.toMap(), 'tx_id': null});
    }
    final title = '${d.donorName} 찬조';
    if (idx >= 0) {
      final old = _txs[idx];
      _txs[idx] = old.copyWith(
        title: title,
        amount: d.amount,
        category: d.categoryKey,
        date: _sameDay(old.date, d.date) ? old.date : _dayStamp(d.date),
        tournamentId: d.tournamentId,
        tournamentName: d.tournamentName,
        clubName: d.donorClubName,
      );
      return d;
    }
    final txId = 'tx_don_${DateTime.now().microsecondsSinceEpoch}';
    _txs.add(FinanceTransaction(
      id: txId,
      title: title,
      amount: d.amount,
      isIncome: true,
      category: d.categoryKey,
      date: _dayStamp(d.date),
      clubName: d.donorClubName,
      tournamentId: d.tournamentId,
      tournamentName: d.tournamentName,
      link: '찬조_$txId',
    ));
    return d.copyWith(txId: txId);
  }

  // ── 1회성 이주 ──────────────────────────

  /// 예전 자료에 연동 표시를 붙이고, 장부에 없던 현금 찬조를 수입으로 올린다.
  static Future<void> migrateOnce() async {
    const flag = 'ledger_links_v1';
    if (await StorageService.getFlag(flag)) return;

    final feeTx = {
      for (final p in SampleData.playerFeePayments)
        if (p.txId != null) p.txId!
    };
    final shareTx = {
      for (final s in SampleData.clubShares)
        if (s.txId != null) s.txId!
    };
    final donTx = {
      for (final d in SampleData.donations)
        if (d.txId != null) d.txId!
    };
    for (var i = 0; i < _txs.length; i++) {
      final t = _txs[i];
      if (t.link != null) continue;
      String? kind;
      if (feeTx.contains(t.id)) {
        kind = '협회비';
      } else if (shareTx.contains(t.id)) {
        kind = '분담금';
      } else if (donTx.contains(t.id)) {
        kind = '찬조';
      }
      if (kind != null) _txs[i] = t.copyWith(link: '${kind}_${t.id}');
    }

    for (var i = 0; i < SampleData.donations.length; i++) {
      final d = SampleData.donations[i];
      final hasTx = d.txId != null && _txs.any((t) => t.id == d.txId);
      if (!hasTx && d.kind == DonationKind.cash && d.amount > 0) {
        SampleData.donations[i] =
            syncDonation(Donation.fromMap({...d.toMap(), 'tx_id': null}));
      }
    }

    await SampleData.saveTransactions();
    await SampleData.saveDonations();
    await StorageService.setFlag(flag, true);
  }

  // ── 작은 도움 ───────────────────────────

  static void _replace(FinanceTransaction t) {
    final i = _txs.indexWhere((x) => x.id == t.id);
    if (i >= 0) _txs[i] = t;
  }

  static Future<void> _saveAll() async {
    await SampleData.saveTransactions();
    await SampleData.savePlayerFeePayments();
    await SampleData.saveClubShares();
  }

  static String _p2(int n) => n.toString().padLeft(2, '0');

  static String _nowStr() {
    final d = DateTime.now();
    return '${d.year}-${_p2(d.month)}-${_p2(d.day)} '
        '${_p2(d.hour)}:${_p2(d.minute)}:${_p2(d.second)}';
  }

  /// 날짜만 있는 값을 장부 도장으로. 오늘이면 지금 시각, 아니면 날짜만.
  static String dayStamp(String day) => _dayStamp(day);

  static String _dayStamp(String day) {
    final now = _nowStr();
    if (day.length < 10 || day.substring(0, 10) == now.substring(0, 10)) {
      return now;
    }
    return day.substring(0, 10);
  }

  static bool _sameDay(String a, String b) =>
      a.length >= 10 && b.length >= 10 && a.substring(0, 10) == b.substring(0, 10);

  static String _fmtStamp(String s) =>
      s.length >= 16 ? s.substring(0, 16) : s;

  static String _fmt(int n) {
    final s = n.abs().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return n < 0 ? '-$s원' : '$s원';
  }
}

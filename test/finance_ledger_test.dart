import 'package:badminton_association/models/club_share.dart';
import 'package:badminton_association/models/donation.dart';
import 'package:badminton_association/models/finance_transaction.dart';
import 'package:badminton_association/models/player_fee_payment.dart';
import 'package:badminton_association/services/finance_ledger.dart';
import 'package:badminton_association/services/finance_log.dart';
import 'package:badminton_association/services/sample_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

int balance() => SampleData.transactions
    .fold(0, (s, t) => s + (t.isIncome ? t.amount : -t.amount));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SampleData.transactions.clear();
    SampleData.playerFeePayments.clear();
    SampleData.clubShares.clear();
    SampleData.donations.clear();
  });

  test('협회비 반납 → 짝이 생기고 납부가 풀리며, 되돌리면 원래대로', () async {
    const txId = 'tx_pfp_1';
    SampleData.playerFeePayments.add(const PlayerFeePayment(
        id: 'pfp_1',
        playerId: 'p1',
        playerName: '가상선수',
        clubId: 'c1',
        clubName: '가상클럽',
        year: 2026,
        amount: 15000,
        date: '2026-03-01',
        txId: txId));
    SampleData.transactions.add(const FinanceTransaction(
        id: txId,
        title: '가상클럽 - 가상선수',
        amount: 15000,
        isIncome: true,
        category: '협회비',
        date: '2026-03-01 10:00:00',
        link: '협회비_$txId'));

    final live = SampleData.transactions.first;
    expect(FinanceLedger.actionOf(live), LedgerAction.refund);

    await FinanceLedger.refund(live);
    expect(SampleData.transactions.length, 2);
    expect(balance(), 0);
    expect(SampleData.playerFeePayments, isEmpty);
    final paid = SampleData.transactions.firstWhere((t) => t.id == txId);
    final back = SampleData.transactions.firstWhere((t) => t.id != txId);
    expect(FinanceLedger.isSettledPaid(paid), isTrue);
    expect(FinanceLedger.isRefund(back), isTrue);
    expect(FinanceLedger.actionOf(back), LedgerAction.locked);

    expect(FinanceLedger.undoBlocker(back), isNull);
    expect(await FinanceLedger.undoRefund(back), isTrue);
    expect(SampleData.transactions.length, 1);
    expect(balance(), 15000);
    expect(FinanceLedger.isLinkedLive(SampleData.transactions.first), isTrue);
    expect(SampleData.playerFeePayments.single.txId, txId);

    final log = await FinanceLog.load();
    expect(log.map((e) => e.what), ['협회비 반납 되돌림', '협회비 반납']);
  });

  test('다시 납부했으면 반납 되돌리기를 막는다', () async {
    const txId = 'tx_pfp_2';
    SampleData.playerFeePayments.add(const PlayerFeePayment(
        id: 'pfp_2',
        playerId: 'p1',
        playerName: '가상선수',
        clubId: 'c1',
        clubName: '가상클럽',
        year: 2026,
        amount: 15000,
        date: '2026-03-01',
        txId: txId));
    SampleData.transactions.add(const FinanceTransaction(
        id: txId,
        title: 't',
        amount: 15000,
        isIncome: true,
        category: '협회비',
        date: '2026-03-01',
        link: '협회비_$txId'));
    await FinanceLedger.refund(SampleData.transactions.first);
    SampleData.playerFeePayments.add(const PlayerFeePayment(
        id: 'pfp_3',
        playerId: 'p1',
        playerName: '가상선수',
        clubId: 'c1',
        clubName: '가상클럽',
        year: 2026,
        amount: 15000,
        date: '2026-04-01'));
    expect(FinanceLedger.undoBlocker(SampleData.transactions.first), isNotNull);
    expect(await FinanceLedger.undoRefund(SampleData.transactions.first),
        isFalse);
  });

  test('분담금 반납은 미납으로, 되돌리면 납부로', () async {
    const txId = 'tx_cs_1';
    SampleData.clubShares.add(const ClubShare(
        id: 'cs_1',
        tournamentId: 't1',
        tournamentName: '가상대회',
        clubId: 'c1',
        clubName: '가상클럽',
        amount: 100000,
        paid: true,
        paidDate: '2026-05-01',
        txId: txId));
    SampleData.transactions.add(const FinanceTransaction(
        id: txId,
        title: '가상클럽 분담금',
        amount: 100000,
        isIncome: true,
        category: '분담금',
        date: '2026-05-01',
        link: '분담금_$txId'));
    await FinanceLedger.refund(SampleData.transactions.first);
    expect(SampleData.clubShares.single.paid, isFalse);
    expect(balance(), 0);
    expect(await FinanceLedger.undoRefund(SampleData.transactions.first),
        isTrue);
    expect(SampleData.clubShares.single.paid, isTrue);
    expect(SampleData.clubShares.single.txId, txId);
    expect(balance(), 100000);
  });

  test('현금 찬조는 장부 수입으로, 물품으로 바꾸면 줄이 빠진다', () {
    var d = const Donation(id: 'don_1', donorName: '가상후원', amount: 50000);
    d = FinanceLedger.syncDonation(d);
    expect(d.txId, isNotNull);
    expect(SampleData.transactions.single.link, '찬조_${d.txId}');
    expect(FinanceLedger.actionOf(SampleData.transactions.single),
        LedgerAction.donation);

    d = FinanceLedger.syncDonation(d.copyWith(kind: DonationKind.item));
    expect(d.txId, isNull);
    expect(SampleData.transactions, isEmpty);
  });

  test('손으로 적은 줄은 바로 지운다', () async {
    SampleData.transactions.add(const FinanceTransaction(
        id: 'u_1',
        title: '가상체육관',
        amount: 30000,
        isIncome: false,
        date: '2026-06-01 12:00:00'));
    expect(FinanceLedger.actionOf(SampleData.transactions.first),
        LedgerAction.delete);
    await FinanceLedger.deletePlain(SampleData.transactions.first);
    expect(SampleData.transactions, isEmpty);
  });

  test('예전 date-only 자료와 . 구분자도 읽는다', () {
    final t = FinanceTransaction.fromMap(
        {'id': 'u_1', 'title': 'x', 'amount': 1, 'date': '2026.06.01'});
    expect(t.date, '2026-06-01');
    expect(t.phone, '');
    expect(t.link, isNull);
  });
}

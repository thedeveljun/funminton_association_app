import '../models/club.dart';
import '../models/player.dart';
import '../models/tournament.dart';
import '../models/finance_transaction.dart';
import '../models/club_share.dart';
import '../models/donation.dart';
import '../models/association_fee_payment.dart';
import '../models/player_fee_payment.dart';
import '../models/scheduled_tournament.dart';
import '../models/admin_records.dart';
import 'storage_service.dart';

class SampleData {
  SampleData._();

  // ─── 데이터 컨테이너 ──────────────────────────
  // 모든 샘플은 제거됨. 사용자 입력만 영속화된다.
  static List<Tournament> tournaments = [];
  static List<ClubShare> clubShares = [];
  static List<AssociationFeePayment> feePayments = [];
  static List<PlayerFeePayment> playerFeePayments = [];
  static List<Donation> donations = [];
  static final List<Notice> notices = [];
  static final List<BoardMeeting> boards = [];
  static final List<OfficialDoc> docs = [];
  static final List<ScheduledTournament> scheduledTournaments = [];
  static final List<Club> clubs = [];
  static final List<Player> players = [];
  static final List<FinanceTransaction> transactions = [];

  /// 영구 저장 대상 판별 — id에 '_'가 포함된 데이터만 사용자 입력으로 간주.
  /// 사용자 입력 id 컨벤션은 모두 '_' 포함(예: club_<ms>, t_<ms>, cs_<μs>, …).
  static bool _isUserId(String id) => id.contains('_');

  /// 로드된 데이터 중 사용자 데이터만 in-memory 리스트에 머지.
  /// (기존에 들어있던 사용자 데이터는 제거 후 재삽입 — 중복 방지)
  static void _mergeUser<T>(
    List<T> dest,
    List<T>? loaded,
    String Function(T) idOf,
    String label,
  ) {
    if (loaded == null) return;
    dest.removeWhere((e) => _isUserId(idOf(e)));
    final userOnly = loaded.where((e) => _isUserId(idOf(e))).toList();
    dest.addAll(userOnly);
    if (userOnly.isNotEmpty) {
      print('✅ 저장된 사용자 $label ${userOnly.length}건 로드됨');
    }
  }

  static Future<void> loadFromStorage() async {
    _mergeUser<Club>(
        clubs, await StorageService.loadClubs(), (c) => c.id, '클럽');
    _mergeUser<Player>(
        players, await StorageService.loadPlayers(), (p) => p.id, '선수');
    _mergeUser<Tournament>(tournaments,
        await StorageService.loadTournaments(), (t) => t.id, '대회');
    _mergeUser<ScheduledTournament>(
        scheduledTournaments,
        await StorageService.loadScheduledTournaments(),
        (s) => s.id,
        '외부 대회 일정');
    _mergeUser<Notice>(
        notices, await StorageService.loadNotices(), (n) => n.id, '공지사항');
    _mergeUser<BoardMeeting>(
        boards, await StorageService.loadBoards(), (b) => b.id, '이사회');
    _mergeUser<OfficialDoc>(
        docs, await StorageService.loadDocs(), (d) => d.id, '공문');
    _mergeUser<PlayerFeePayment>(
        playerFeePayments,
        await StorageService.loadPlayerFeePayments(),
        (p) => p.id,
        '협회비 납부');
    _mergeUser<FinanceTransaction>(transactions,
        await StorageService.loadTransactions(), (t) => t.id, '거래');
    _mergeUser<ClubShare>(clubShares, await StorageService.loadClubShares(),
        (s) => s.id, '분담금');
    _mergeUser<Donation>(donations, await StorageService.loadDonations(),
        (d) => d.id, '찬조');
  }

  /// 사용자가 입력한(`_` 포함 id) 데이터만 저장.
  static Future<void> saveClubs() => StorageService.saveClubs(
      clubs.where((c) => _isUserId(c.id)).toList());
  static Future<void> savePlayers() => StorageService.savePlayers(
      players.where((p) => _isUserId(p.id)).toList());
  static Future<void> saveTournaments() => StorageService.saveTournaments(
      tournaments.where((t) => _isUserId(t.id)).toList());
  static Future<void> saveScheduledTournaments() =>
      StorageService.saveScheduledTournaments(
          scheduledTournaments.where((s) => _isUserId(s.id)).toList());
  static Future<void> saveNotices() => StorageService.saveNotices(
      notices.where((n) => _isUserId(n.id)).toList());
  static Future<void> saveBoards() => StorageService.saveBoards(
      boards.where((b) => _isUserId(b.id)).toList());
  static Future<void> saveDocs() => StorageService.saveDocs(
      docs.where((d) => _isUserId(d.id)).toList());
  static Future<void> savePlayerFeePayments() =>
      StorageService.savePlayerFeePayments(
          playerFeePayments.where((p) => _isUserId(p.id)).toList());
  static Future<void> saveTransactions() => StorageService.saveTransactions(
      transactions.where((t) => _isUserId(t.id)).toList());
  static Future<void> saveClubShares() => StorageService.saveClubShares(
      clubShares.where((s) => _isUserId(s.id)).toList());
  static Future<void> saveDonations() => StorageService.saveDonations(
      donations.where((d) => _isUserId(d.id)).toList());

  /// 음수/비정상 나이 → birthDate 로부터 재계산.
  /// 비표준 birthDate(예: '1998-11-27') → 6자리 YYMMDD 표준형으로 정규화.
  /// 앱 시작 시 1회만 호출.
  static Future<int> repairBrokenAges() async {
    int fixed = 0;
    for (var i = 0; i < players.length; i++) {
      final p = players[i];
      final normBd = Player.normalizeBirthDate(p.birthDate);
      final ageOk = p.age >= 0 && p.age <= 120;
      final bdOk = p.birthDate.isEmpty || p.birthDate == normBd;
      if (ageOk && bdOk) continue;
      final newBd = normBd.isEmpty && p.birthDate.isNotEmpty
          ? p.birthDate
          : normBd;
      final newAge = Player.calcAgeFromBirthDate(p.birthDate);
      players[i] = Player(
        id: p.id,
        name: p.name,
        gender: p.gender,
        birthDate: newBd,
        grade: p.grade,
        clubId: p.clubId,
        clubName: p.clubName,
        phone: p.phone,
        regNumber: p.regNumber,
        age: newAge,
        awards: p.awards,
      );
      fixed++;
    }
    if (fixed > 0) await savePlayers();
    return fixed;
  }
}

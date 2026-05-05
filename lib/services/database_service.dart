import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _db;

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'badminton_association.db'),
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE tournaments ADD COLUMN venue_courts TEXT DEFAULT \'\'');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE tournaments ADD COLUMN venue_addresses TEXT DEFAULT \'\'');
    }
    if (oldVersion < 4) {
      await _migrateV4(db);
    }
  }

  /// v4 마이그레이션: eventType/targetGrade 다중값화 + 라벨 통일.
  /// 실패해도 앱 진입을 막지 않음 — fromMap 의 런타임 정규화가 안전망.
  Future<void> _migrateV4(Database db) async {
    try {
      // ① eventType '전체' → 풀어쓰기
      await db.execute(
        "UPDATE tournaments SET event_type = '혼복,남복,여복' "
        "WHERE TRIM(event_type) = '전체'",
      );
      // ② eventType 빈 값/NULL → '혼복'
      await db.execute(
        "UPDATE tournaments SET event_type = '혼복' "
        "WHERE event_type IS NULL OR TRIM(event_type) = ''",
      );
      // ③ targetGrade '전체' → 풀어쓰기
      await db.execute(
        "UPDATE tournaments SET target_grade = 'A조,B조,C조,D조,초심조' "
        "WHERE TRIM(target_grade) = '전체'",
      );
      // ④ A급/B급/C급/D급 → A조/B조/C조/D조
      for (final letter in ['A', 'B', 'C', 'D']) {
        await db.execute(
          "UPDATE tournaments "
          "SET target_grade = REPLACE(target_grade, '$letter급', '$letter조') "
          "WHERE target_grade LIKE '%$letter급%'",
        );
      }
      // 초심 → 초심조 (재실행 안전 가드)
      await db.execute(
        "UPDATE tournaments "
        "SET target_grade = REPLACE(target_grade, '초심', '초심조') "
        "WHERE target_grade LIKE '%초심%' "
        "AND target_grade NOT LIKE '%초심조%'",
      );
      // ⑤ targetGrade 빈 값/NULL → 전체 풀어쓰기
      await db.execute(
        "UPDATE tournaments SET target_grade = 'A조,B조,C조,D조,초심조' "
        "WHERE target_grade IS NULL OR TRIM(target_grade) = ''",
      );
    } catch (e) {
      // 마이그레이션 실패는 fromMap 정규화로 폴백되므로 로깅만.
      // ignore: avoid_print
      print('[DB] _migrateV4 failed (non-fatal): $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 클럽 테이블
    await db.execute('''
      CREATE TABLE clubs (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        region TEXT,
        member_type TEXT,
        president_name TEXT,
        president_phone TEXT,
        secretary_name TEXT,
        secretary_phone TEXT,
        venue TEXT,
        founded_at TEXT,
        member_count INTEGER DEFAULT 0,
        fee_paid INTEGER DEFAULT 0
      )
    ''');

    // 선수 테이블 (주민번호 앞자리만 저장)
    await db.execute('''
      CREATE TABLE players (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        gender TEXT,
        birth_date TEXT,
        grade TEXT,
        club_id TEXT,
        club_name TEXT,
        phone TEXT,
        reg_number TEXT,
        age INTEGER,
        FOREIGN KEY (club_id) REFERENCES clubs(id)
      )
    ''');

    // 대회 테이블
    await db.execute('''
      CREATE TABLE tournaments (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        venue TEXT,
        venue_courts TEXT DEFAULT '',
        venue_addresses TEXT DEFAULT '',
        event_type TEXT,
        target_grade TEXT,
        entry_fee INTEGER DEFAULT 0,
        status TEXT DEFAULT 'upcoming',
        participant_count INTEGER DEFAULT 0
      )
    ''');

    // 경기 테이블
    await db.execute('''
      CREATE TABLE matches (
        id TEXT PRIMARY KEY,
        tournament_id TEXT,
        court_number INTEGER,
        venue_id TEXT,
        venue_name TEXT,
        match_type TEXT,
        team_a_ids TEXT,
        team_b_ids TEXT,
        score_a INTEGER,
        score_b INTEGER,
        is_done INTEGER DEFAULT 0,
        day_number INTEGER DEFAULT 1,
        FOREIGN KEY (tournament_id) REFERENCES tournaments(id)
      )
    ''');

    // 재정 테이블
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        type TEXT,
        category TEXT,
        date TEXT,
        club_id TEXT,
        memo TEXT
      )
    ''');
  }

  Database get db => _db!;

  // 클럽 CRUD
  Future<List<Map<String, dynamic>>> getClubs() async =>
      await db.query('clubs', orderBy: 'name');

  Future<void> insertClub(Map<String, dynamic> club) async =>
      await db.insert('clubs', club);

  Future<void> updateClub(Map<String, dynamic> club) async =>
      await db.update('clubs', club, where: 'id = ?', whereArgs: [club['id']]);

  Future<void> deleteClub(String id) async =>
      await db.delete('clubs', where: 'id = ?', whereArgs: [id]);

  // 선수 CRUD
  Future<List<Map<String, dynamic>>> getPlayers(
      {String? grade, String? gender}) async {
    String where = '';
    final args = <dynamic>[];
    if (grade != null && grade != '전체') {
      where = 'grade = ?';
      args.add(grade);
    }
    if (gender != null) {
      where += where.isEmpty ? 'gender = ?' : ' AND gender = ?';
      args.add(gender);
    }
    return await db.query(
      'players',
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name',
    );
  }

  Future<void> insertPlayer(Map<String, dynamic> player) async =>
      await db.insert('players', player);

  // 재정 CRUD
  Future<List<Map<String, dynamic>>> getTransactions() async =>
      await db.query('transactions', orderBy: 'date DESC');

  Future<void> insertTransaction(Map<String, dynamic> tx) async =>
      await db.insert('transactions', tx);
}

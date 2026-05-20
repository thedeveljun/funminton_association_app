import 'package:badminton_association/score/l10n/app_locale.dart';

/// 모든 UI/TTS 텍스트 번역. `S(locale).xxx` 형태로 사용.
class S {
  final AppLocale locale;
  const S(this.locale);

  // ── App ───────────────────────────────────────────────────────
  String get appTitle {
    switch (locale) {
      case AppLocale.ko:
        return '배드민턴 점수판';
      case AppLocale.en:
        return 'Badminton Scoreboard';
      case AppLocale.zh:
        return '羽毛球比分板';
      case AppLocale.ja:
        return 'バドミントン スコアボード';
      case AppLocale.ms:
        return 'Papan Skor Badminton';
      case AppLocale.id:
        return 'Papan Skor Bulu Tangkis';
      case AppLocale.hi:
        return 'बैडमिंटन स्कोरबोर्ड';
      case AppLocale.da:
        return 'Badminton Scoreboard';
    }
  }

  // ── 점수판 ────────────────────────────────────────────────────
  String get score {
    switch (locale) {
      case AppLocale.ko:
        return '스코어';
      case AppLocale.en:
        return 'SCORE';
      case AppLocale.zh:
        return '比分';
      case AppLocale.ja:
        return 'スコア';
      case AppLocale.ms:
        return 'SKOR';
      case AppLocale.id:
        return 'SKOR';
      case AppLocale.hi:
        return 'स्कोर';
      case AppLocale.da:
        return 'POINT';
    }
  }

  String get deuceOn {
    switch (locale) {
      case AppLocale.ko:
        return '듀스 ON';
      case AppLocale.en:
        return 'DEUCE ON';
      case AppLocale.zh:
        return '平分 开';
      case AppLocale.ja:
        return 'デュース ON';
      case AppLocale.ms:
        return 'DEUCE HIDUP';
      case AppLocale.id:
        return 'DEUCE NYALA';
      case AppLocale.hi:
        return 'ड्यूस चालू';
      case AppLocale.da:
        return 'DEUCE TIL';
    }
  }

  String get deuceOff {
    switch (locale) {
      case AppLocale.ko:
        return '듀스 OFF';
      case AppLocale.en:
        return 'DEUCE OFF';
      case AppLocale.zh:
        return '平分 关';
      case AppLocale.ja:
        return 'デュース OFF';
      case AppLocale.ms:
        return 'DEUCE MATI';
      case AppLocale.id:
        return 'DEUCE MATI';
      case AppLocale.hi:
        return 'ड्यूस बंद';
      case AppLocale.da:
        return 'DEUCE FRA';
    }
  }

  // ── 하단 버튼 ────────────────────────────────────────────────
  String get undo {
    switch (locale) {
      case AppLocale.ko:
        return '점수취소';
      case AppLocale.en:
        return 'Undo';
      case AppLocale.zh:
        return '撤销';
      case AppLocale.ja:
        return '取り消し';
      case AppLocale.ms:
        return 'Buat Asal';
      case AppLocale.id:
        return 'Batalkan';
      case AppLocale.hi:
        return 'पूर्ववत';
      case AppLocale.da:
        return 'Fortryd';
    }
  }

  String get reset {
    switch (locale) {
      case AppLocale.ko:
        return '점수리셋';
      case AppLocale.en:
        return 'Reset';
      case AppLocale.zh:
        return '重置';
      case AppLocale.ja:
        return 'リセット';
      case AppLocale.ms:
        return 'Set Semula';
      case AppLocale.id:
        return 'Atur Ulang';
      case AppLocale.hi:
        return 'रीसेट';
      case AppLocale.da:
        return 'Nulstil';
    }
  }

  String get exitGame {
    switch (locale) {
      case AppLocale.ko:
        return '게임종료';
      case AppLocale.en:
        return 'Exit';
      case AppLocale.zh:
        return '退出';
      case AppLocale.ja:
        return '終了';
      case AppLocale.ms:
        return 'Keluar';
      case AppLocale.id:
        return 'Keluar';
      case AppLocale.hi:
        return 'बाहर';
      case AppLocale.da:
        return 'Afslut';
    }
  }

  String get saveRecord {
    switch (locale) {
      case AppLocale.ko:
        return '기록저장';
      case AppLocale.en:
        return 'Save';
      case AppLocale.zh:
        return '保存';
      case AppLocale.ja:
        return '保存';
      case AppLocale.ms:
        return 'Simpan';
      case AppLocale.id:
        return 'Simpan';
      case AppLocale.hi:
        return 'सहेजें';
      case AppLocale.da:
        return 'Gem';
    }
  }

  String get share {
    switch (locale) {
      case AppLocale.ko:
        return '공유';
      case AppLocale.en:
        return 'Share';
      case AppLocale.zh:
        return '分享';
      case AppLocale.ja:
        return '共有';
      case AppLocale.ms:
        return 'Kongsi';
      case AppLocale.id:
        return 'Bagikan';
      case AppLocale.hi:
        return 'शेयर';
      case AppLocale.da:
        return 'Del';
    }
  }

  String get shareSubject {
    switch (locale) {
      case AppLocale.ko:
        return '배드민턴 경기 결과';
      case AppLocale.en:
        return 'Badminton Match Result';
      case AppLocale.zh:
        return '羽毛球比赛结果';
      case AppLocale.ja:
        return 'バドミントンの試合結果';
      case AppLocale.ms:
        return 'Keputusan Perlawanan Badminton';
      case AppLocale.id:
        return 'Hasil Pertandingan Bulu Tangkis';
      case AppLocale.hi:
        return 'बैडमिंटन मैच परिणाम';
      case AppLocale.da:
        return 'Badminton-kampresultat';
    }
  }

  String get chooseServe {
    switch (locale) {
      case AppLocale.ko:
        return '서브선택';
      case AppLocale.en:
        return 'Serve';
      case AppLocale.zh:
        return '发球';
      case AppLocale.ja:
        return 'サーブ';
      case AppLocale.ms:
        return 'Servis';
      case AppLocale.id:
        return 'Servis';
      case AppLocale.hi:
        return 'सर्व';
      case AppLocale.da:
        return 'Serv';
    }
  }

  // ── 다이얼로그 공통 ───────────────────────────────────────────
  String get cancel {
    switch (locale) {
      case AppLocale.ko:
        return '취소';
      case AppLocale.en:
        return 'Cancel';
      case AppLocale.zh:
        return '取消';
      case AppLocale.ja:
        return 'キャンセル';
      case AppLocale.ms:
        return 'Batal';
      case AppLocale.id:
        return 'Batal';
      case AppLocale.hi:
        return 'रद्द करें';
      case AppLocale.da:
        return 'Annullér';
    }
  }

  String get confirm {
    switch (locale) {
      case AppLocale.ko:
        return '확인';
      case AppLocale.en:
        return 'OK';
      case AppLocale.zh:
        return '确定';
      case AppLocale.ja:
        return 'OK';
      case AppLocale.ms:
        return 'OK';
      case AppLocale.id:
        return 'OK';
      case AppLocale.hi:
        return 'ठीक है';
      case AppLocale.da:
        return 'OK';
    }
  }

  String get close {
    switch (locale) {
      case AppLocale.ko:
        return '닫기';
      case AppLocale.en:
        return 'Close';
      case AppLocale.zh:
        return '关闭';
      case AppLocale.ja:
        return '閉じる';
      case AppLocale.ms:
        return 'Tutup';
      case AppLocale.id:
        return 'Tutup';
      case AppLocale.hi:
        return 'बंद करें';
      case AppLocale.da:
        return 'Luk';
    }
  }

  // ── 점수 리셋 ────────────────────────────────────────────────
  String get resetTitle {
    switch (locale) {
      case AppLocale.ko:
        return '점수리셋';
      case AppLocale.en:
        return 'Reset Score';
      case AppLocale.zh:
        return '重置比分';
      case AppLocale.ja:
        return 'スコアをリセット';
      case AppLocale.ms:
        return 'Set Semula Skor';
      case AppLocale.id:
        return 'Atur Ulang Skor';
      case AppLocale.hi:
        return 'स्कोर रीसेट करें';
      case AppLocale.da:
        return 'Nulstil point';
    }
  }

  String get resetMessage {
    switch (locale) {
      case AppLocale.ko:
        return '점수를 리셋하시겠습니까?';
      case AppLocale.en:
        return 'Reset the score?';
      case AppLocale.zh:
        return '确定要重置比分吗？';
      case AppLocale.ja:
        return 'スコアをリセットしますか？';
      case AppLocale.ms:
        return 'Set semula skor?';
      case AppLocale.id:
        return 'Atur ulang skor?';
      case AppLocale.hi:
        return 'स्कोर रीसेट करें?';
      case AppLocale.da:
        return 'Nulstil pointene?';
    }
  }

  // ── 게임 종료 ────────────────────────────────────────────────
  String get exitTitle {
    switch (locale) {
      case AppLocale.ko:
        return '게임종료';
      case AppLocale.en:
        return 'Exit Game';
      case AppLocale.zh:
        return '退出比赛';
      case AppLocale.ja:
        return 'ゲーム終了';
      case AppLocale.ms:
        return 'Keluar Permainan';
      case AppLocale.id:
        return 'Keluar Permainan';
      case AppLocale.hi:
        return 'खेल से बाहर';
      case AppLocale.da:
        return 'Afslut spil';
    }
  }

  String get exitMessage {
    switch (locale) {
      case AppLocale.ko:
        return '게임을 종료하시겠습니까?';
      case AppLocale.en:
        return 'Exit the game?';
      case AppLocale.zh:
        return '确定要退出比赛吗？';
      case AppLocale.ja:
        return 'ゲームを終了しますか？';
      case AppLocale.ms:
        return 'Keluar daripada permainan?';
      case AppLocale.id:
        return 'Keluar dari permainan?';
      case AppLocale.hi:
        return 'खेल से बाहर जाएं?';
      case AppLocale.da:
        return 'Afslut spillet?';
    }
  }

  // ── 서브 선택 ────────────────────────────────────────────────
  String get firstServer {
    switch (locale) {
      case AppLocale.ko:
        return '첫 서브 선수';
      case AppLocale.en:
        return 'First Server';
      case AppLocale.zh:
        return '首先发球者';
      case AppLocale.ja:
        return '最初のサーバー';
      case AppLocale.ms:
        return 'Penyervis Pertama';
      case AppLocale.id:
        return 'Server Pertama';
      case AppLocale.hi:
        return 'पहला सर्वर';
      case AppLocale.da:
        return 'Første server';
    }
  }

  String get opponentFirstServer {
    switch (locale) {
      case AppLocale.ko:
        return '상대편 첫 서브 선수';
      case AppLocale.en:
        return 'Opponent First Server';
      case AppLocale.zh:
        return '对方首先发球者';
      case AppLocale.ja:
        return '相手の最初のサーバー';
      case AppLocale.ms:
        return 'Penyervis Pertama Lawan';
      case AppLocale.id:
        return 'Server Pertama Lawan';
      case AppLocale.hi:
        return 'विपक्षी का पहला सर्वर';
      case AppLocale.da:
        return 'Modstanderens første server';
    }
  }

  // ── 목표 점수 / 듀스 ─────────────────────────────────────────
  String get targetScoreTitle {
    switch (locale) {
      case AppLocale.ko:
        return '목표 점수 / 듀스 설정';
      case AppLocale.en:
        return 'Target Score / Deuce';
      case AppLocale.zh:
        return '目标分数 / 平分';
      case AppLocale.ja:
        return '目標スコア / デュース';
      case AppLocale.ms:
        return 'Skor Sasaran / Deuce';
      case AppLocale.id:
        return 'Skor Target / Deuce';
      case AppLocale.hi:
        return 'लक्ष्य स्कोर / ड्यूस';
      case AppLocale.da:
        return 'Målpoint / Deuce';
    }
  }

  String points(int n) {
    switch (locale) {
      case AppLocale.ko:
        return '$n점';
      case AppLocale.en:
        return '$n pts';
      case AppLocale.zh:
        return '$n 分';
      case AppLocale.ja:
        return '$n点';
      case AppLocale.ms:
        return '$n mata';
      case AppLocale.id:
        return '$n poin';
      case AppLocale.hi:
        return '$n अंक';
      case AppLocale.da:
        return '$n point';
    }
  }

  String get deuceLabel {
    switch (locale) {
      case AppLocale.ko:
        return '듀스 있음';
      case AppLocale.en:
        return 'Deuce';
      case AppLocale.zh:
        return '启用平分';
      case AppLocale.ja:
        return 'デュースあり';
      case AppLocale.ms:
        return 'Deuce';
      case AppLocale.id:
        return 'Deuce';
      case AppLocale.hi:
        return 'ड्यूस';
      case AppLocale.da:
        return 'Deuce';
    }
  }

  String get deuceDescription {
    switch (locale) {
      case AppLocale.ko:
        return '2점 차이 날 때까지 계속 진행';
      case AppLocale.en:
        return 'Play continues until 2-point lead';
      case AppLocale.zh:
        return '直到领先2分为止';
      case AppLocale.ja:
        return '2点差まで続行';
      case AppLocale.ms:
        return 'Diteruskan sehingga jurang 2 mata';
      case AppLocale.id:
        return 'Lanjut hingga selisih 2 poin';
      case AppLocale.hi:
        return '2 अंक का अंतर होने तक जारी';
      case AppLocale.da:
        return 'Fortsætter indtil 2 points føring';
    }
  }

  // ── 저장: 나의 팀 선택 ───────────────────────────────────────
  String get selectMyTeamTitle {
    switch (locale) {
      case AppLocale.ko:
        return '나의 팀 선택';
      case AppLocale.en:
        return 'Select My Team';
      case AppLocale.zh:
        return '选择我方';
      case AppLocale.ja:
        return '自分のチームを選択';
      case AppLocale.ms:
        return 'Pilih Pasukan Saya';
      case AppLocale.id:
        return 'Pilih Tim Saya';
      case AppLocale.hi:
        return 'मेरी टीम चुनें';
      case AppLocale.da:
        return 'Vælg mit hold';
    }
  }

  String get selectMyTeamDescription {
    switch (locale) {
      case AppLocale.ko:
        return '승/패 기준이 될 나의 팀을 선택하세요.';
      case AppLocale.en:
        return 'Choose your team for win/loss tracking.';
      case AppLocale.zh:
        return '请选择记录胜负的我方队伍。';
      case AppLocale.ja:
        return '勝敗の基準となる自分のチームを選択してください。';
      case AppLocale.ms:
        return 'Pilih pasukan anda untuk rekod menang/kalah.';
      case AppLocale.id:
        return 'Pilih tim Anda untuk catatan menang/kalah.';
      case AppLocale.hi:
        return 'जीत/हार के लिए अपनी टीम चुनें।';
      case AppLocale.da:
        return 'Vælg dit hold til at registrere sejr/nederlag.';
    }
  }

  String get skipMyTeam {
    switch (locale) {
      case AppLocale.ko:
        return '선택 안 함';
      case AppLocale.en:
        return 'Skip';
      case AppLocale.zh:
        return '不选择';
      case AppLocale.ja:
        return '選択しない';
      case AppLocale.ms:
        return 'Langkau';
      case AppLocale.id:
        return 'Lewati';
      case AppLocale.hi:
        return 'छोड़ें';
      case AppLocale.da:
        return 'Spring over';
    }
  }

  String get win {
    switch (locale) {
      case AppLocale.ko:
        return '승';
      case AppLocale.en:
        return 'Win';
      case AppLocale.zh:
        return '胜';
      case AppLocale.ja:
        return '勝';
      case AppLocale.ms:
        return 'Menang';
      case AppLocale.id:
        return 'Menang';
      case AppLocale.hi:
        return 'जीत';
      case AppLocale.da:
        return 'Sejr';
    }
  }

  String get loss {
    switch (locale) {
      case AppLocale.ko:
        return '패';
      case AppLocale.en:
        return 'Loss';
      case AppLocale.zh:
        return '负';
      case AppLocale.ja:
        return '負';
      case AppLocale.ms:
        return 'Kalah';
      case AppLocale.id:
        return 'Kalah';
      case AppLocale.hi:
        return 'हार';
      case AppLocale.da:
        return 'Tab';
    }
  }

  String get draw {
    switch (locale) {
      case AppLocale.ko:
        return '무';
      case AppLocale.en:
        return 'Draw';
      case AppLocale.zh:
        return '平';
      case AppLocale.ja:
        return '分';
      case AppLocale.ms:
        return 'Seri';
      case AppLocale.id:
        return 'Seri';
      case AppLocale.hi:
        return 'ड्रॉ';
      case AppLocale.da:
        return 'Uafgj.';
    }
  }

  // ── 저장 메시지 ──────────────────────────────────────────────
  String get gameOverSavePrompt {
    switch (locale) {
      case AppLocale.ko:
        return '\'기록저장\' 버튼으로 기록 남기기\n(길게 누르면 저장된 기록 보기)';
      case AppLocale.en:
        return 'Tap \'Save\' to keep this record.\n(Long-press to view saved records)';
      case AppLocale.zh:
        return '点击「保存」保留记录。\n（长按查看已保存的记录）';
      case AppLocale.ja:
        return '「保存」ボタンで記録を残せます。\n（長押しで保存済み記録を表示）';
      case AppLocale.ms:
        return 'Tekan \'Simpan\' untuk menyimpan rekod.\n(Tekan lama untuk lihat rekod tersimpan)';
      case AppLocale.id:
        return 'Tekan \'Simpan\' untuk menyimpan.\n(Tekan lama untuk melihat rekaman tersimpan)';
      case AppLocale.hi:
        return '\'सहेजें\' पर टैप करें।\n(सहेजे गए रिकॉर्ड देखने के लिए लंबे समय तक दबाएं)';
      case AppLocale.da:
        return 'Tryk \'Gem\' for at gemme.\n(Tryk længe for at se gemte registreringer)';
    }
  }

  String get needTwoPlayers {
    switch (locale) {
      case AppLocale.ko:
        return '선수명을 2명 이상 입력해야 저장할 수 있습니다';
      case AppLocale.en:
        return 'Enter at least 2 player names to save';
      case AppLocale.zh:
        return '请至少输入 2 名选手才能保存';
      case AppLocale.ja:
        return '2名以上の選手名を入力してください';
      case AppLocale.ms:
        return 'Masukkan sekurang-kurangnya 2 nama pemain untuk menyimpan';
      case AppLocale.id:
        return 'Masukkan minimal 2 nama pemain untuk menyimpan';
      case AppLocale.hi:
        return 'सहेजने के लिए कम से कम 2 खिलाड़ी नाम दर्ज करें';
      case AppLocale.da:
        return 'Indtast mindst 2 spillernavne for at gemme';
    }
  }

  String needMinScore(int n) {
    switch (locale) {
      case AppLocale.ko:
        return '점수가 $n점 이상이어야 기록저장할 수 있습니다';
      case AppLocale.en:
        return 'Need at least $n points to save';
      case AppLocale.zh:
        return '比分至少达到 $n 分才能保存';
      case AppLocale.ja:
        return '$n点以上で保存できます';
      case AppLocale.ms:
        return 'Perlukan sekurang-kurangnya $n mata untuk menyimpan';
      case AppLocale.id:
        return 'Perlu minimal $n poin untuk menyimpan';
      case AppLocale.hi:
        return 'सहेजने के लिए कम से कम $n अंक चाहिए';
      case AppLocale.da:
        return 'Kræver mindst $n point for at gemme';
    }
  }

  String get duplicateSaveBlocked {
    switch (locale) {
      case AppLocale.ko:
        return '같은 선수명, 점수, 설정으로는 바로 중복 저장할 수 없습니다';
      case AppLocale.en:
        return 'Cannot save the same players/score/settings twice in a row';
      case AppLocale.zh:
        return '相同的选手、比分、设置无法立即重复保存';
      case AppLocale.ja:
        return '同じ選手・スコア・設定での連続保存はできません';
      case AppLocale.ms:
        return 'Tidak boleh menyimpan rekod yang sama secara berturut-turut';
      case AppLocale.id:
        return 'Tidak dapat menyimpan rekaman yang sama berturut-turut';
      case AppLocale.hi:
        return 'समान रिकॉर्ड को लगातार सहेजा नहीं जा सकता';
      case AppLocale.da:
        return 'Kan ikke gemme samme registrering to gange i træk';
    }
  }

  String get savedSuccess {
    switch (locale) {
      case AppLocale.ko:
        return '경기 기록이 저장되었습니다';
      case AppLocale.en:
        return 'Match record saved';
      case AppLocale.zh:
        return '已保存比赛记录';
      case AppLocale.ja:
        return '試合記録を保存しました';
      case AppLocale.ms:
        return 'Rekod perlawanan disimpan';
      case AppLocale.id:
        return 'Rekaman pertandingan tersimpan';
      case AppLocale.hi:
        return 'मैच रिकॉर्ड सहेजा गया';
      case AppLocale.da:
        return 'Kamp gemt';
    }
  }

  String get savedFailed {
    switch (locale) {
      case AppLocale.ko:
        return '저장에 실패했습니다';
      case AppLocale.en:
        return 'Save failed';
      case AppLocale.zh:
        return '保存失败';
      case AppLocale.ja:
        return '保存に失敗しました';
      case AppLocale.ms:
        return 'Gagal menyimpan';
      case AppLocale.id:
        return 'Gagal menyimpan';
      case AppLocale.hi:
        return 'सहेजना विफल';
      case AppLocale.da:
        return 'Kunne ikke gemme';
    }
  }

  // ── 선수명 입력 ──────────────────────────────────────────────
  String get editPlayersTitle {
    switch (locale) {
      case AppLocale.ko:
        return '선수명 입력';
      case AppLocale.en:
        return 'Edit Players';
      case AppLocale.zh:
        return '编辑选手';
      case AppLocale.ja:
        return '選手名入力';
      case AppLocale.ms:
        return 'Edit Pemain';
      case AppLocale.id:
        return 'Edit Pemain';
      case AppLocale.hi:
        return 'खिलाड़ी संपादित करें';
      case AppLocale.da:
        return 'Rediger spillere';
    }
  }

  String get editPlayersHeading {
    switch (locale) {
      case AppLocale.ko:
        return '선수명을 입력하세요';
      case AppLocale.en:
        return 'Enter player names';
      case AppLocale.zh:
        return '请输入选手姓名';
      case AppLocale.ja:
        return '選手名を入力してください';
      case AppLocale.ms:
        return 'Masukkan nama pemain';
      case AppLocale.id:
        return 'Masukkan nama pemain';
      case AppLocale.hi:
        return 'खिलाड़ी का नाम दर्ज करें';
      case AppLocale.da:
        return 'Indtast spillernavne';
    }
  }

  // ── 저장된 기록 ──────────────────────────────────────────────
  String get savedMatchesTitle {
    switch (locale) {
      case AppLocale.ko:
        return '최근 저장 기록';
      case AppLocale.en:
        return 'Recent Records';
      case AppLocale.zh:
        return '最近保存的记录';
      case AppLocale.ja:
        return '最近の保存記録';
      case AppLocale.ms:
        return 'Rekod Terkini';
      case AppLocale.id:
        return 'Rekaman Terbaru';
      case AppLocale.hi:
        return 'हाल के रिकॉर्ड';
      case AppLocale.da:
        return 'Seneste registreringer';
    }
  }

  String get deleteAll {
    switch (locale) {
      case AppLocale.ko:
        return '전체삭제';
      case AppLocale.en:
        return 'Delete All';
      case AppLocale.zh:
        return '全部删除';
      case AppLocale.ja:
        return 'すべて削除';
      case AppLocale.ms:
        return 'Padam Semua';
      case AppLocale.id:
        return 'Hapus Semua';
      case AppLocale.hi:
        return 'सभी हटाएं';
      case AppLocale.da:
        return 'Slet alle';
    }
  }

  String get deleteAllConfirm {
    switch (locale) {
      case AppLocale.ko:
        return '저장된 기록을 모두 삭제하시겠습니까?';
      case AppLocale.en:
        return 'Delete all saved records?';
      case AppLocale.zh:
        return '确定要删除全部记录吗？';
      case AppLocale.ja:
        return '保存されたすべての記録を削除しますか？';
      case AppLocale.ms:
        return 'Padam semua rekod tersimpan?';
      case AppLocale.id:
        return 'Hapus semua rekaman tersimpan?';
      case AppLocale.hi:
        return 'सभी सहेजे गए रिकॉर्ड हटाएं?';
      case AppLocale.da:
        return 'Slet alle gemte registreringer?';
    }
  }

  String get deleteAllDone {
    switch (locale) {
      case AppLocale.ko:
        return '저장된 기록을 모두 삭제했습니다';
      case AppLocale.en:
        return 'All records deleted';
      case AppLocale.zh:
        return '已删除全部记录';
      case AppLocale.ja:
        return 'すべての記録を削除しました';
      case AppLocale.ms:
        return 'Semua rekod dipadam';
      case AppLocale.id:
        return 'Semua rekaman dihapus';
      case AppLocale.hi:
        return 'सभी रिकॉर्ड हटा दिए गए';
      case AppLocale.da:
        return 'Alle registreringer slettet';
    }
  }

  String get deleteSelected {
    switch (locale) {
      case AppLocale.ko:
        return '선택삭제';
      case AppLocale.en:
        return 'Delete Selected';
      case AppLocale.zh:
        return '删除所选';
      case AppLocale.ja:
        return '選択削除';
      case AppLocale.ms:
        return 'Padam Pilihan';
      case AppLocale.id:
        return 'Hapus Pilihan';
      case AppLocale.hi:
        return 'चयनित हटाएं';
      case AppLocale.da:
        return 'Slet valgte';
    }
  }

  String deleteSelectedConfirm(int n) {
    switch (locale) {
      case AppLocale.ko:
        return '선택한 $n개 기록을 삭제하시겠습니까?';
      case AppLocale.en:
        return n == 1
            ? 'Delete the selected record?'
            : 'Delete $n selected records?';
      case AppLocale.zh:
        return '确定要删除所选的 $n 条记录吗？';
      case AppLocale.ja:
        return '選択した $n 件の記録を削除しますか？';
      case AppLocale.ms:
        return 'Padam $n rekod yang dipilih?';
      case AppLocale.id:
        return 'Hapus $n rekaman yang dipilih?';
      case AppLocale.hi:
        return 'चयनित $n रिकॉर्ड हटाएं?';
      case AppLocale.da:
        return 'Slet $n valgte registreringer?';
    }
  }

  String get deleteSelectedDone {
    switch (locale) {
      case AppLocale.ko:
        return '선택한 기록을 삭제했습니다';
      case AppLocale.en:
        return 'Selected records deleted';
      case AppLocale.zh:
        return '已删除所选记录';
      case AppLocale.ja:
        return '選択した記録を削除しました';
      case AppLocale.ms:
        return 'Rekod yang dipilih dipadam';
      case AppLocale.id:
        return 'Rekaman terpilih dihapus';
      case AppLocale.hi:
        return 'चयनित रिकॉर्ड हटा दिए गए';
      case AppLocale.da:
        return 'Valgte registreringer slettet';
    }
  }

  String get selectAll {
    switch (locale) {
      case AppLocale.ko:
        return '전체선택';
      case AppLocale.en:
        return 'Select All';
      case AppLocale.zh:
        return '全选';
      case AppLocale.ja:
        return 'すべて選択';
      case AppLocale.ms:
        return 'Pilih Semua';
      case AppLocale.id:
        return 'Pilih Semua';
      case AppLocale.hi:
        return 'सभी चुनें';
      case AppLocale.da:
        return 'Vælg alle';
    }
  }

  String get deselectAll {
    switch (locale) {
      case AppLocale.ko:
        return '전체해제';
      case AppLocale.en:
        return 'Clear All';
      case AppLocale.zh:
        return '取消全选';
      case AppLocale.ja:
        return '選択解除';
      case AppLocale.ms:
        return 'Nyahpilih';
      case AppLocale.id:
        return 'Batal Pilih';
      case AppLocale.hi:
        return 'चयन हटाएं';
      case AppLocale.da:
        return 'Fravælg';
    }
  }

  String selectedCount(int n) {
    switch (locale) {
      case AppLocale.ko:
        return '선택 $n개';
      case AppLocale.en:
        return '$n selected';
      case AppLocale.zh:
        return '已选 $n 项';
      case AppLocale.ja:
        return '$n 件選択';
      case AppLocale.ms:
        return '$n dipilih';
      case AppLocale.id:
        return '$n terpilih';
      case AppLocale.hi:
        return '$n चयनित';
      case AppLocale.da:
        return '$n valgt';
    }
  }

  String get nothingToDelete {
    switch (locale) {
      case AppLocale.ko:
        return '삭제할 기록을 선택하세요';
      case AppLocale.en:
        return 'Select records to delete';
      case AppLocale.zh:
        return '请选择要删除的记录';
      case AppLocale.ja:
        return '削除する記録を選択してください';
      case AppLocale.ms:
        return 'Pilih rekod untuk dipadam';
      case AppLocale.id:
        return 'Pilih rekaman untuk dihapus';
      case AppLocale.hi:
        return 'हटाने के लिए रिकॉर्ड चुनें';
      case AppLocale.da:
        return 'Vælg registreringer at slette';
    }
  }

  String get noSavedRecords {
    switch (locale) {
      case AppLocale.ko:
        return '저장된 기록이 없습니다';
      case AppLocale.en:
        return 'No saved records';
      case AppLocale.zh:
        return '没有保存的记录';
      case AppLocale.ja:
        return '保存された記録はありません';
      case AppLocale.ms:
        return 'Tiada rekod tersimpan';
      case AppLocale.id:
        return 'Tidak ada rekaman tersimpan';
      case AppLocale.hi:
        return 'कोई सहेजा गया रिकॉर्ड नहीं';
      case AppLocale.da:
        return 'Ingen gemte registreringer';
    }
  }

  // ── 설정 페이지 ──────────────────────────────────────────────
  String get settingsTitle {
    switch (locale) {
      case AppLocale.ko:
        return '설정';
      case AppLocale.en:
        return 'Settings';
      case AppLocale.zh:
        return '设置';
      case AppLocale.ja:
        return '設定';
      case AppLocale.ms:
        return 'Tetapan';
      case AppLocale.id:
        return 'Pengaturan';
      case AppLocale.hi:
        return 'सेटिंग्स';
      case AppLocale.da:
        return 'Indstillinger';
    }
  }

  String get languageLabel {
    switch (locale) {
      case AppLocale.ko:
        return '언어';
      case AppLocale.en:
        return 'Language';
      case AppLocale.zh:
        return '语言';
      case AppLocale.ja:
        return '言語';
      case AppLocale.ms:
        return 'Bahasa';
      case AppLocale.id:
        return 'Bahasa';
      case AppLocale.hi:
        return 'भाषा';
      case AppLocale.da:
        return 'Sprog';
    }
  }

  // ── 선수 placeholder ─────────────────────────────────────────
  String playerPlaceholder(int n) {
    switch (locale) {
      case AppLocale.ko:
        return '선수$n';
      case AppLocale.en:
        return 'Player $n';
      case AppLocale.zh:
        return '选手$n';
      case AppLocale.ja:
        return '選手$n';
      case AppLocale.ms:
        return 'Pemain $n';
      case AppLocale.id:
        return 'Pemain $n';
      case AppLocale.hi:
        return 'खिलाड़ी $n';
      case AppLocale.da:
        return 'Spiller $n';
    }
  }

  /// 저장된 placeholder 이름을 표시용으로 현지화.
  /// 내부 sentinel은 '선수1'..'선수4'로 유지되므로, 표시할 때만 변환.
  String localizedPlayerName(String raw) {
    final t = raw.trim();
    if (t == '선수1') return playerPlaceholder(1);
    if (t == '선수2') return playerPlaceholder(2);
    if (t == '선수3') return playerPlaceholder(3);
    if (t == '선수4') return playerPlaceholder(4);
    return raw;
  }

  // ── TTS 안내 문구 ────────────────────────────────────────────
  String ttsScore(int a, int b) {
    switch (locale) {
      case AppLocale.ko:
        return '$a 대 $b';
      case AppLocale.en:
        return '$a to $b';
      case AppLocale.zh:
        return '$a 比 $b';
      case AppLocale.ja:
        return '$a 対 $b';
      case AppLocale.ms:
        return '$a lawan $b';
      case AppLocale.id:
        return '$a lawan $b';
      case AppLocale.hi:
        return '$a बनाम $b';
      case AppLocale.da:
        return '$a mod $b';
    }
  }

  String ttsGameOver(int a, int b) {
    switch (locale) {
      case AppLocale.ko:
        return '게임 종료! $a 대 $b';
      case AppLocale.en:
        return 'Game over! $a to $b';
      case AppLocale.zh:
        return '比赛结束！$a 比 $b';
      case AppLocale.ja:
        return 'ゲーム終了！$a 対 $b';
      case AppLocale.ms:
        return 'Permainan tamat! $a lawan $b';
      case AppLocale.id:
        return 'Permainan selesai! $a lawan $b';
      case AppLocale.hi:
        return 'खेल समाप्त! $a बनाम $b';
      case AppLocale.da:
        return 'Spil slut! $a mod $b';
    }
  }

  String get ttsDeuce {
    switch (locale) {
      case AppLocale.ko:
        return '듀스';
      case AppLocale.en:
        return 'Deuce';
      case AppLocale.zh:
        return '平分';
      case AppLocale.ja:
        return 'デュース';
      case AppLocale.ms:
        return 'Deuce';
      case AppLocale.id:
        return 'Deuce';
      case AppLocale.hi:
        return 'ड्यूस';
      case AppLocale.da:
        return 'Deuce';
    }
  }

  String ttsGamePoint(int a, int b) {
    switch (locale) {
      case AppLocale.ko:
        return '게임포인트! $a 대 $b';
      case AppLocale.en:
        return 'Game point! $a to $b';
      case AppLocale.zh:
        return '赛点！$a 比 $b';
      case AppLocale.ja:
        return 'ゲームポイント！$a 対 $b';
      case AppLocale.ms:
        return 'Mata permainan! $a lawan $b';
      case AppLocale.id:
        return 'Match point! $a lawan $b';
      case AppLocale.hi:
        return 'गेम पॉइंट! $a बनाम $b';
      case AppLocale.da:
        return 'Game point! $a mod $b';
    }
  }

  String ttsCourtChangeWithScore(int a, int b) {
    switch (locale) {
      case AppLocale.ko:
        return '$a 대 $b 코트 체인지';
      case AppLocale.en:
        return '$a to $b. Court change';
      case AppLocale.zh:
        return '$a 比 $b 交换场地';
      case AppLocale.ja:
        return '$a 対 $b コートチェンジ';
      case AppLocale.ms:
        return '$a lawan $b. Tukar gelanggang';
      case AppLocale.id:
        return '$a lawan $b. Ganti lapangan';
      case AppLocale.hi:
        return '$a बनाम $b. कोर्ट बदलें';
      case AppLocale.da:
        return '$a mod $b. Banebytte';
    }
  }

  String get ttsCourtChange {
    switch (locale) {
      case AppLocale.ko:
        return '코트 체인지';
      case AppLocale.en:
        return 'Court change';
      case AppLocale.zh:
        return '交换场地';
      case AppLocale.ja:
        return 'コートチェンジ';
      case AppLocale.ms:
        return 'Tukar gelanggang';
      case AppLocale.id:
        return 'Ganti lapangan';
      case AppLocale.hi:
        return 'कोर्ट बदलें';
      case AppLocale.da:
        return 'Banebytte';
    }
  }

  String get ttsUndo {
    switch (locale) {
      case AppLocale.ko:
        return '점수 취소';
      case AppLocale.en:
        return 'Score undone';
      case AppLocale.zh:
        return '撤销得分';
      case AppLocale.ja:
        return '得点取り消し';
      case AppLocale.ms:
        return 'Skor dibatalkan';
      case AppLocale.id:
        return 'Skor dibatalkan';
      case AppLocale.hi:
        return 'स्कोर रद्द';
      case AppLocale.da:
        return 'Point annulleret';
    }
  }
}

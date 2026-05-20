/// 표시 순서: 한국어 → 배드민턴 인구 많은 순.
/// 코드 문자열로 저장하므로 enum 순서 변경은 기존 사용자 설정에 영향 없음.
enum AppLocale {
  ko,
  zh,
  id,
  ms,
  ja,
  hi,
  en,
  da,
}

extension AppLocaleX on AppLocale {
  String get code {
    switch (this) {
      case AppLocale.ko:
        return 'ko';
      case AppLocale.zh:
        return 'zh';
      case AppLocale.id:
        return 'id';
      case AppLocale.ms:
        return 'ms';
      case AppLocale.ja:
        return 'ja';
      case AppLocale.hi:
        return 'hi';
      case AppLocale.en:
        return 'en';
      case AppLocale.da:
        return 'da';
    }
  }

  String get ttsCode {
    switch (this) {
      case AppLocale.ko:
        return 'ko-KR';
      case AppLocale.zh:
        return 'zh-CN';
      case AppLocale.id:
        return 'id-ID';
      case AppLocale.ms:
        return 'ms-MY';
      case AppLocale.ja:
        return 'ja-JP';
      case AppLocale.hi:
        return 'hi-IN';
      case AppLocale.en:
        return 'en-US';
      case AppLocale.da:
        return 'da-DK';
    }
  }

  String get displayName {
    switch (this) {
      case AppLocale.ko:
        return '한국어';
      case AppLocale.zh:
        return '中文（简体）';
      case AppLocale.id:
        return 'Bahasa Indonesia';
      case AppLocale.ms:
        return 'Bahasa Melayu';
      case AppLocale.ja:
        return '日本語';
      case AppLocale.hi:
        return 'हिन्दी';
      case AppLocale.en:
        return 'English';
      case AppLocale.da:
        return 'Dansk';
    }
  }

  static AppLocale fromCode(String? code) {
    switch (code) {
      case 'zh':
        return AppLocale.zh;
      case 'id':
        return AppLocale.id;
      case 'ms':
        return AppLocale.ms;
      case 'ja':
        return AppLocale.ja;
      case 'hi':
        return AppLocale.hi;
      case 'en':
        return AppLocale.en;
      case 'da':
        return AppLocale.da;
      default:
        return AppLocale.ko;
    }
  }
}

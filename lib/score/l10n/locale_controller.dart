import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badminton_association/score/l10n/app_locale.dart';

class LocaleController {
  static const String _prefsKey = 'app_locale_v1';
  static final ValueNotifier<AppLocale> notifier =
      ValueNotifier<AppLocale>(AppLocale.ko);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      notifier.value = AppLocaleX.fromCode(code);
    } catch (_) {
      // 기본값(한국어) 유지
    }
  }

  static Future<void> setLocale(AppLocale locale) async {
    notifier.value = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, locale.code);
    } catch (_) {}
  }
}

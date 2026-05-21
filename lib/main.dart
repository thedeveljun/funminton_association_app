import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/root_gate.dart';
import 'services/auth_service.dart';
import 'services/sample_data.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 저장된 데이터 로드 (있으면 그걸 쓰고, 없으면 기본값 사용)
  await SampleData.loadFromStorage();
  final fixed = await SampleData.repairBrokenAges();
  debugPrint('[migration] 잘못된 나이 ${fixed}명 복구');

  // 협회별 협회비 단가 (저장값이 있으면 적용)
  final savedFeeUnit = await StorageService.loadPlayerFeeUnit();
  if (savedFeeUnit != null) AppConfig.playerFeeUnit = savedFeeUnit;

  await AuthService.init();

  runApp(const BadmintonAssociationApp());
}

class BadmintonAssociationApp extends StatelessWidget {
  const BadmintonAssociationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '배드민턴 협회',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      // 한국어 로컬라이제이션 — TimePicker / DatePicker 등 머티리얼 위젯 라벨이 한글로.
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootGate(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
    );
  }
}

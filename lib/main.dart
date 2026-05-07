import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/root_gate.dart';
import 'services/auth_service.dart';
import 'services/sample_data.dart';

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
      home: const RootGate(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
    );
  }
}

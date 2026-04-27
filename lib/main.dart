import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_screen.dart';
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
      home: const HomeScreen(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
    );
  }
}

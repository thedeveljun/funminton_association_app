import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// 진입점 분기 위젯.
/// - 미등록 → RegisterScreen
/// - 등록됨 + 미로그인 → LoginScreen
/// - 로그인됨 → HomeScreen
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _loading = true;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final reg = await AuthService.isRegistered();
    if (!mounted) return;
    setState(() {
      _registered = reg;
      _loading = false;
    });
  }

  void _onAuthSuccess() {
    if (!mounted) return;
    setState(() {
      _registered = true;
    });
  }

  void _onLogout() {
    AuthService.logout();
    if (!mounted) return;
    setState(() {}); // 로그아웃 시 LoginScreen 으로 다시 노출
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_registered) {
      return RegisterScreen(onDone: _onAuthSuccess);
    }
    if (!AuthService.isLoggedIn) {
      return LoginScreen(onDone: _onAuthSuccess);
    }
    return HomeScreen(onLogout: _onLogout);
  }
}

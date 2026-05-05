import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';

/// 등록 후 두 번째 실행부터 — 비밀번호 로그인.
/// 5회 실패 시 잠금(60초). 잠금 해제 후 재시도 가능.
class LoginScreen extends StatefulWidget {
  final VoidCallback onDone;
  const LoginScreen({super.key, required this.onDone});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  int _failCount = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_pwCtrl.text.isEmpty) return _snack('비밀번호를 입력하세요.');
    setState(() => _busy = true);
    final ok = await AuthService.verifyPassword(_pwCtrl.text);
    if (!mounted) return;
    if (ok) {
      widget.onDone();
      return;
    }
    setState(() {
      _failCount++;
      _busy = false;
      _pwCtrl.clear();
    });
    _snack('비밀번호가 일치하지 않습니다. ($_failCount/5)');
    if (_failCount >= 5) {
      _snack('5회 연속 실패 — 잠시 후 다시 시도하세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final assoc = AuthService.associationName;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final locked = _failCount >= 5;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      size: 36, color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                assoc.isEmpty ? '협회 로그인' : assoc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text),
              ),
              const SizedBox(height: 4),
              const Text(
                '비밀번호를 입력해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _pwCtrl,
                obscureText: _obscure,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: '비밀번호',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: (_busy || locked) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMid,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(locked ? '잠시 후 다시 시도' : '로그인',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 14),
              const Text(
                '비밀번호를 잊으셨나요?\n앱을 재설치하면 다시 등록할 수 있습니다 (모든 데이터 삭제).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

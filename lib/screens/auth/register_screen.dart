import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';

/// 첫 실행 화면 — 협회명·회장·관리자·비밀번호 등록.
class RegisterScreen extends StatefulWidget {
  final VoidCallback onDone;
  const RegisterScreen({super.key, required this.onDone});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _assocCtrl = TextEditingController();
  final _presCtrl = TextEditingController();
  final _adminCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _assocCtrl.dispose();
    _presCtrl.dispose();
    _adminCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final assoc = _assocCtrl.text.trim();
    final pres = _presCtrl.text.trim();
    final admin = _adminCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pw2 = _pwConfirmCtrl.text;

    if (assoc.isEmpty) return _snack('협회명을 입력하세요.');
    if (pres.isEmpty) return _snack('회장 이름을 입력하세요.');
    if (admin.isEmpty) return _snack('협회 관리자 이름을 입력하세요.');
    if (pw.length < 4) return _snack('비밀번호는 4자 이상이어야 합니다.');
    if (pw != pw2) return _snack('비밀번호가 일치하지 않습니다.');

    setState(() => _busy = true);
    await AuthService.register(
      associationName: assoc,
      presidentName: pres,
      adminName: admin,
      password: pw,
    );
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMid,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      size: 34, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Text('협회 등록',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text)),
              const SizedBox(height: 4),
              const Text(
                '처음 사용하시는 협회 정보를 등록해주세요.\n등록 후에는 비밀번호로 로그인합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              _label('협회명'),
              _field(_assocCtrl, hint: '예: 과천시배드민턴협회'),
              const SizedBox(height: 10),
              _label('회장 이름'),
              _field(_presCtrl, hint: '예: 김철수'),
              const SizedBox(height: 10),
              _label('협회 관리자 이름'),
              _field(_adminCtrl, hint: '예: 이영희'),
              const SizedBox(height: 18),
              _label('비밀번호 (4자 이상)'),
              _pwField(_pwCtrl, hint: '비밀번호 입력'),
              const SizedBox(height: 10),
              _label('비밀번호 확인'),
              _pwField(_pwConfirmCtrl, hint: '비밀번호 재입력'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMid,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    : const Text('등록하고 시작',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              const Text(
                '※ 비밀번호는 디바이스에만 저장됩니다.\n분실 시 앱을 재설치해야 하며, 모든 데이터가 삭제됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text2)),
      );

  Widget _field(TextEditingController c, {String? hint}) => TextField(
        controller: c,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        ),
      );

  Widget _pwField(TextEditingController c, {String? hint}) => TextField(
        controller: c,
        obscureText: _obscure,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 0),
          suffixIcon: IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 0),
            icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:badminton_association/score/l10n/app_strings.dart';
import 'package:badminton_association/score/l10n/locale_controller.dart';
import 'package:badminton_association/score/models/result_models.dart';

class BulkPlayerEditPage extends StatefulWidget {
  final String leftPlayer1;
  final String leftPlayer2;
  final String rightPlayer1;
  final String rightPlayer2;

  const BulkPlayerEditPage({
    super.key,
    required this.leftPlayer1,
    required this.leftPlayer2,
    required this.rightPlayer1,
    required this.rightPlayer2,
  });

  @override
  State<BulkPlayerEditPage> createState() => _BulkPlayerEditPageState();
}

class _BulkPlayerEditPageState extends State<BulkPlayerEditPage> {
  late final TextEditingController _left1Controller;
  late final TextEditingController _left2Controller;
  late final TextEditingController _right1Controller;
  late final TextEditingController _right2Controller;

  late final FocusNode _left1Focus;
  late final FocusNode _left2Focus;
  late final FocusNode _right1Focus;
  late final FocusNode _right2Focus;

  S get _s => S(LocaleController.notifier.value);

  /// 내부 sentinel 값(예: '선수1')이면 빈 문자열로 표시.
  String _displayOrEmpty(String value, String sentinel) {
    return value.trim() == sentinel ? '' : value.trim();
  }

  // 포커스 들어오는 순간 기존 텍스트 전체 선택 → 바로 타이핑하면 덮어써짐
  FocusNode _makeSelectAllFocusNode(TextEditingController controller) {
    final node = FocusNode();
    node.addListener(() {
      if (node.hasFocus && controller.text.isNotEmpty) {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
    });
    return node;
  }

  @override
  void initState() {
    super.initState();
    _left1Controller =
        TextEditingController(text: _displayOrEmpty(widget.leftPlayer1, '선수1'));
    _left2Controller =
        TextEditingController(text: _displayOrEmpty(widget.leftPlayer2, '선수2'));
    _right1Controller = TextEditingController(
        text: _displayOrEmpty(widget.rightPlayer1, '선수3'));
    _right2Controller = TextEditingController(
        text: _displayOrEmpty(widget.rightPlayer2, '선수4'));

    _left1Focus = _makeSelectAllFocusNode(_left1Controller);
    _left2Focus = _makeSelectAllFocusNode(_left2Controller);
    _right1Focus = _makeSelectAllFocusNode(_right1Controller);
    _right2Focus = _makeSelectAllFocusNode(_right2Controller);

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _left1Controller.dispose();
    _left2Controller.dispose();
    _right1Controller.dispose();
    _right2Controller.dispose();
    _left1Focus.dispose();
    _left2Focus.dispose();
    _right1Focus.dispose();
    _right2Focus.dispose();
    super.dispose();
  }

  void _swapTop() {
    final temp = _left1Controller.text;
    _left1Controller.text = _right1Controller.text;
    _right1Controller.text = temp;
    setState(() {});
  }

  void _swapBottom() {
    final temp = _left2Controller.text;
    _left2Controller.text = _right2Controller.text;
    _right2Controller.text = temp;
    setState(() {});
  }

  void _submit() {
    Navigator.pop(
      context,
      BulkPlayerEditResult(
        leftPlayer1: _left1Controller.text,
        leftPlayer2: _left2Controller.text,
        rightPlayer1: _right1Controller.text,
        rightPlayer2: _right2Controller.text,
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: Colors.grey, fontSize: 17, fontWeight: FontWeight.w400),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      counterText: '',
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 2.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF7E57C2), width: 2.3),
      ),
    );
  }

  Widget _playerField(
      {required TextEditingController controller,
      required FocusNode focusNode,
      required String hint}) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 12,
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\n'))],
        style: const TextStyle(
            color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w600),
        decoration: _fieldDecoration(hint),
      ),
    );
  }

  Widget _swapButton(VoidCallback onTap) {
    return Material(
      color: const Color(0xFF1E88E5),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child:
              Icon(Icons.swap_horiz_rounded, color: Colors.black87, size: 20),
        ),
      ),
    );
  }

  Widget _actionButton(
      {required String text,
      required VoidCallback onTap,
      required bool filled}) {
    if (filled) {
      return SizedBox(
        width: 108,
        height: 41,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7E57C2),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          onPressed: onTap,
          child: Text(text,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      );
    }
    return SizedBox(
      width: 108,
      height: 41,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF7E57C2), width: 1.8),
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        onPressed: onTap,
        child: Text(text,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3EEF7),
        elevation: 0,
        centerTitle: true,
        title: Text(s.editPlayersTitle,
            style: const TextStyle(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.w400)),
        iconTheme: const IconThemeData(color: Colors.black, size: 30),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 22, 18, bottomInset + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.editPlayersHeading,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                      child: _playerField(
                          controller: _left1Controller,
                          focusNode: _left1Focus,
                          hint: s.playerPlaceholder(1))),
                  const SizedBox(width: 10),
                  _swapButton(_swapTop),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _playerField(
                          controller: _right1Controller,
                          focusNode: _right1Focus,
                          hint: s.playerPlaceholder(3))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _playerField(
                          controller: _left2Controller,
                          focusNode: _left2Focus,
                          hint: s.playerPlaceholder(2))),
                  const SizedBox(width: 10),
                  _swapButton(_swapBottom),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _playerField(
                          controller: _right2Controller,
                          focusNode: _right2Focus,
                          hint: s.playerPlaceholder(4))),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionButton(
                      text: s.cancel,
                      onTap: () => Navigator.pop(context),
                      filled: false),
                  const SizedBox(width: 18),
                  _actionButton(text: s.confirm, onTap: _submit, filled: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

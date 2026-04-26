import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_association/main.dart';

void main() {
  testWidgets('App boots without error', (WidgetTester tester) async {
    await tester.pumpWidget(const BadmintonAssociationApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

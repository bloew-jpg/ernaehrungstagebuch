import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ernaehrungstagebuch/main.dart';

void main() {
  testWidgets('starts and shows the diary title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ErnaehrungsApp());
    await tester.pump();

    expect(find.text('Mein Ernährungstagebuch'), findsOneWidget);
  });
}

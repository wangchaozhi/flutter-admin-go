import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/app/mobile_app.dart';

void main() {
  testWidgets('app builds', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MobileApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('心遇婚恋'), findsOneWidget);
    expect(find.text('记住登录信息'), findsOneWidget);
  });
}

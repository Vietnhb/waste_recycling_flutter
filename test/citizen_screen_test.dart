import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/controllers/app_controller.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';
import 'package:waste_recycling_flutter/src/ui/app/waste_app.dart';

void main() {
  testWidgets('Citizen screen opens without build exceptions', (tester) async {
    final controller = AppController()
      ..booting = false
      ..baseUrl = 'http://localhost:8080/api'
      ..token = 'test-token'
      ..user = const User(
        id: 2,
        email: 'citizen@gmail.com',
        fullName: 'Nguyen Van Citizen',
        role: 'CITIZEN',
      );

    await tester.pumpWidget(WasteApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('CÔNG DÂN'), findsOneWidget);
    expect(find.text('Không gian'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Không gian'));
    await tester.pumpAndSettle();

    expect(find.text('Báo cáo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

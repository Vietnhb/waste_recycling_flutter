import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/controllers/app_controller.dart';
import 'package:waste_recycling_flutter/src/ui/app/waste_app.dart';

void main() {
  testWidgets('shows the Flutter waste recycling home screen', (tester) async {
    final controller = AppController()..booting = false;

    await tester.pumpWidget(WasteApp(controller: controller));

    expect(find.text('Tái Chế Xanh'), findsOneWidget);
    expect(find.text('Waste recycling network'), findsOneWidget);
  });
}

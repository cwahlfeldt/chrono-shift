import 'package:basic/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke test — main menu renders', (tester) async {
    await tester.pumpWidget(const ChronoSwipeApp());
    await tester.pump();

    expect(find.text('CHRONO'), findsOneWidget);
    expect(find.text('SWIPE'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}

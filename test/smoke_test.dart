import 'package:chrono_swipe/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke test — main menu renders', (tester) async {
    await tester.pumpWidget(const ChronoSwipeApp());
    await tester.pump();

    expect(find.text('CHRONO'), findsOneWidget);
    expect(find.text('SHIFT'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}

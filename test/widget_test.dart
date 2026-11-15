import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_tv_cast/main.dart';

void main() {
  testWidgets('shows brand title', (tester) async {
    await tester.pumpWidget(const TvWifiCastApp());
    expect(find.text('TV WiFi Cast'), findsOneWidget);
    expect(find.text('Start receiver'), findsOneWidget);
  });
}

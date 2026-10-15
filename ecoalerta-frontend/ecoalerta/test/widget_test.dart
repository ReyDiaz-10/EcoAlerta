import 'package:flutter_test/flutter_test.dart';
import 'package:ecoalerta/main.dart';

void main() {
  testWidgets('EcoAlerta basic interface smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EcoAlertaApp());
    await tester.pump();

    expect(find.text('Bienvenido a EcoAlerta'), findsOneWidget);
    expect(find.text('¿Qué es EcoAlerta?'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
  });
}

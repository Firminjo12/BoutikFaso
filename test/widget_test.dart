// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:boutik_faso/app.dart';

void main() {
  testWidgets('affiche la page d’accueil Boutik Faso', (tester) async {
    await tester.pumpWidget(const BoutikFasoApp());
    await tester.pumpAndSettle();

    expect(find.text('Boutik Faso'), findsOneWidget);
    expect(find.text('Votre commerce, près de chez vous.'), findsOneWidget);
  });
}

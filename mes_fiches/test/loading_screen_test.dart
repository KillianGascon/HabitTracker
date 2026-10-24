import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_fiches/screens/loading_screen.dart';
import 'package:mes_fiches/widgets/app_logo.dart';

Widget _wrap(Brightness brightness) => MediaQuery(
      data: MediaQueryData(platformBrightness: brightness),
      child: const Directionality(textDirection: TextDirection.ltr, child: LoadingScreen()),
    );

Color _background(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byType(ColoredBox).first).color;

void main() {
  testWidgets('loader : logo, nom de l’appli, fond violet', (tester) async {
    await tester.pumpWidget(_wrap(Brightness.light));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Mes fiches'), findsOneWidget);
    expect(_background(tester), LoadingScreen.lightBackground);
  });

  testWidgets('loader : fond sombre en mode sombre', (tester) async {
    await tester.pumpWidget(_wrap(Brightness.dark));
    expect(_background(tester), LoadingScreen.darkBackground);
  });
}

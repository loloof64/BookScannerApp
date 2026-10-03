import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:book_scanner_app/main.dart';

void main() {
  group('BookScannerPage Tests', () {
    testWidgets('App launches correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // Vérifie que l'application démarre correctement
      expect(find.text('Book Scanner'), findsOneWidget);
    });

    testWidgets('Image selection buttons are displayed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      // Vérifie que les boutons de sélection d'image sont présents
      expect(find.text('From Gallery'), findsOneWidget);
      expect(find.text('From Camera'), findsOneWidget);
    });

    testWidgets('Image display area shows correctly when no image selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MyApp());

      // Vérifie que le message "No image selected" est affiché
      expect(find.text('No image selected'), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_scanner_app/screens/crop_preview_screen.dart';

void main() {
  group('CropPreviewScreen', () {
    testWidgets('displays loading indicator while processing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CropPreviewScreen(
            imagePath: 'test_image.jpg',
            corners: [
              const Offset(50, 50),
              const Offset(250, 50),
              const Offset(250, 250),
              const Offset(50, 250),
            ],
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays confirm and redo buttons after processing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CropPreviewScreen(
            imagePath: 'test_image.jpg',
            corners: [
              const Offset(50, 50),
              const Offset(250, 50),
              const Offset(250, 250),
              const Offset(50, 250),
            ],
          ),
        ),
      );

      // Wait for processing to complete
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify buttons are present
      expect(find.byType(ElevatedButton), findsWidgets);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Redo Crop'), findsOneWidget);
    });
  });
}

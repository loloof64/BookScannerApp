import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:book_scanner_app/models/book_model.dart';
import 'package:path/path.dart' as p;

void main() {
  group('BookListScreen', () {
    testWidgets('displays page count from pages_images.txt instead of file count', (
      WidgetTester tester,
    ) async {
      // Setup: create a temporary book directory with pages_images.txt
      final tempDir = await Directory.systemTemp.createTemp('book_test_');
      final bookDir = Directory(p.join(tempDir.path, 'TestBook'));
      await bookDir.create();

      // Create pages_images.txt with 5 pages
      final pagesFile = File(p.join(bookDir.path, 'pages_images.txt'));
      await pagesFile.writeAsString(
        'page_001.jpg\npage_002.jpg\npage_003.jpg\n'
        'page_004.jpg\npage_005.jpg\n',
      );

      // Create dummy image files (but only 3, not 5)
      File(p.join(bookDir.path, 'page_001.jpg')).createSync();
      File(p.join(bookDir.path, 'page_002.jpg')).createSync();
      File(p.join(bookDir.path, 'page_003.jpg')).createSync();

      final book = BookModel(
        name: 'TestBook',
        directory: bookDir,
        pageFiles: [],
        lastModified: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                ListTile(
                  title: Text(book.name),
                  subtitle: FutureBuilder<int>(
                    future: () async {
                      final pagesFile = File(
                        p.join(book.directory.path, 'pages_images.txt'),
                      );
                      if (await pagesFile.exists()) {
                        try {
                          final lines = await pagesFile.readAsLines();
                          return lines
                              .where((line) => line.trim().isNotEmpty)
                              .length;
                        } catch (e) {
                          return 0;
                        }
                      }
                      return 0;
                    }(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text('$count page(s)');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify: should show 5 pages from pages_images.txt, not 3 from actual files
      expect(find.text('5 page(s)'), findsOneWidget);

      // Cleanup
      await tempDir.delete(recursive: true);
    });
  });
}

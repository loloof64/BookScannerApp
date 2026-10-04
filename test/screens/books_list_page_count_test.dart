import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Page count logic', () {
    test('counts lines in pages_images.txt as page count', () async {
      // Setup: create a temporary book directory
      final tempDir = await Directory.systemTemp.createTemp('page_count_test_');
      final pagesFile = File(p.join(tempDir.path, 'pages_images.txt'));

      // Create pages_images.txt with 5 pages
      await pagesFile.writeAsString(
        'page_001.jpg\npage_002.jpg\npage_003.jpg\npage_004.jpg\npage_005.jpg\n',
      );

      // Simulate the logic that books_list_screen should use
      int pageCount;
      if (await pagesFile.exists()) {
        final lines = await pagesFile.readAsLines();
        pageCount = lines.where((line) => line.trim().isNotEmpty).length;
      } else {
        pageCount = 0;
      }

      // Should return 5, not the number of actual image files
      expect(pageCount, equals(5));

      // Cleanup
      await tempDir.delete(recursive: true);
    });
  });
}

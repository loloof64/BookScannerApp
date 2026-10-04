import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Pages images reading', () {
    test(
        'counts non-empty lines in pages_images.txt to get page count',
        () async {
      // Setup: create a temporary book directory with pages_images.txt
      final tempDir = await Directory.systemTemp.createTemp('pages_test_');
      final pagesFile = File(p.join(tempDir.path, 'pages_images.txt'));

      // Create pages_images.txt with 5 pages and some blank lines
      await pagesFile.writeAsString(
        'page_001.jpg\npage_002.jpg\n\npage_003.jpg\n\n\npage_004.jpg\npage_005.jpg\n',
      );

      // Read and count non-empty lines
      final lines = await pagesFile.readAsLines();
      final pageCount =
          lines.where((line) => line.trim().isNotEmpty).length;

      expect(pageCount, equals(5));

      // Cleanup
      await tempDir.delete(recursive: true);
    });
  });
}

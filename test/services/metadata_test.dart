import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Metadata reading', () {
    test(
        'counts non-empty lines in metadata.txt to get page count',
        () async {
      // Setup: create a temporary book directory with metadata.txt
      final tempDir = await Directory.systemTemp.createTemp('metadata_test_');
      final metadataFile = File(p.join(tempDir.path, 'metadata.txt'));

      // Create metadata.txt with 5 pages and some blank lines
      await metadataFile.writeAsString(
        'page_001.jpg\npage_002.jpg\n\npage_003.jpg\n\n\npage_004.jpg\npage_005.jpg\n',
      );

      // Read and count non-empty lines
      final lines = await metadataFile.readAsLines();
      final pageCount =
          lines.where((line) => line.trim().isNotEmpty).length;

      expect(pageCount, equals(5));

      // Cleanup
      await tempDir.delete(recursive: true);
    });
  });
}

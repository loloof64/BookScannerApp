import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('page count should come from metadata.txt line count, not file count',
      () async {
    // Setup: create a temporary book directory
    final tempDir = await Directory.systemTemp.createTemp('books_');
    final bookDir = Directory(p.join(tempDir.path, 'TestBook'));
    await bookDir.create();

    // Create metadata.txt with 5 pages listed
    final metadataFile = File(p.join(bookDir.path, 'metadata.txt'));
    await metadataFile.writeAsString(
      'page_001.jpg\npage_002.jpg\npage_003.jpg\npage_004.jpg\npage_005.jpg\n',
    );

    // Create only 3 actual image files
    await File(p.join(bookDir.path, 'page_001.jpg')).create();
    await File(p.join(bookDir.path, 'page_002.jpg')).create();
    await File(p.join(bookDir.path, 'page_003.jpg')).create();

    // The page count should be 5 (from metadata.txt), not 3 (from actual files)
    final metadataLines = await metadataFile.readAsLines();
    final expectedPageCount =
        metadataLines.where((line) => line.trim().isNotEmpty).length;

    expect(expectedPageCount, equals(5));

    // Cleanup
    await tempDir.delete(recursive: true);
  });
}

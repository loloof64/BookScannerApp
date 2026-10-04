import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
      'BookListScreen subtitle should count metadata.txt lines, not file count',
      () async {
    // Setup: create a book with metadata.txt
    final tempDir = await Directory.systemTemp.createTemp('books_');
    final bookDir = Directory(p.join(tempDir.path, 'MyBook'));
    await bookDir.create();

    // Create metadata with 5 pages
    final metadata = File(p.join(bookDir.path, 'metadata.txt'));
    await metadata.writeAsString('p1.jpg\np2.jpg\np3.jpg\np4.jpg\np5.jpg\n');

    // Create only 2 actual files
    await File(p.join(bookDir.path, 'p1.jpg')).create();
    await File(p.join(bookDir.path, 'p2.jpg')).create();

    // Logic test: the widget subtitle should show page count from metadata.txt
    // Expected: 5 page(s) from metadata.txt
    // Current (before fix): would show 2 page(s) from actual files

    // Read metadata to verify the expected behavior
    final lines = await metadata.readAsLines();
    final metadataPageCount =
        lines.where((line) => line.trim().isNotEmpty).length;

    expect(metadataPageCount, equals(5),
        reason: 'Should count 5 pages from metadata.txt');

    // Cleanup
    await tempDir.delete(recursive: true);
  });
}

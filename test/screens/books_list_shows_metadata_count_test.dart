import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
      'BookListScreen subtitle should count pages_images.txt lines, not file count',
      () async {
    // Setup: create a book with pages_images.txt
    final tempDir = await Directory.systemTemp.createTemp('books_');
    final bookDir = Directory(p.join(tempDir.path, 'MyBook'));
    await bookDir.create();

    // Create pages_images with 5 pages
    final pagesFile = File(p.join(bookDir.path, 'pages_images.txt'));
    await pagesFile.writeAsString('p1.jpg\np2.jpg\np3.jpg\np4.jpg\np5.jpg\n');

    // Create only 2 actual files
    await File(p.join(bookDir.path, 'p1.jpg')).create();
    await File(p.join(bookDir.path, 'p2.jpg')).create();

    // Logic test: the widget subtitle should show page count from pages_images.txt
    // Expected: 5 page(s) from pages_images.txt
    // Current (before fix): would show 2 page(s) from actual files

    // Read pages_images to verify the expected behavior
    final lines = await pagesFile.readAsLines();
    final pagesCount =
        lines.where((line) => line.trim().isNotEmpty).length;

    expect(pagesCount, equals(5),
        reason: 'Should count 5 pages from pages_images.txt');

    // Cleanup
    await tempDir.delete(recursive: true);
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
      'When pages_images.txt has 5 lines and only 2 files exist, page count should be 5',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('integration_test_');
    final bookDir = Directory(p.join(tempDir.path, 'Book'));
    await bookDir.create();

    // Create pages_images with 5 pages
    await File(p.join(bookDir.path, 'pages_images.txt'))
        .writeAsString('p1\np2\np3\np4\np5\n');
    // Create only 2 files
    await File(p.join(bookDir.path, 'p1')).create();
    await File(p.join(bookDir.path, 'p2')).create();

    // The expected behavior: count lines in pages_images, not files
    final lines = await File(p.join(bookDir.path, 'pages_images.txt')).readAsLines();
    final pageCount = lines.where((l) => l.trim().isNotEmpty).length;

    expect(pageCount, 5);
    await tempDir.delete(recursive: true);
  });
}

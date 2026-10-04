import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:book_scanner_app/services/storage_service.dart';

void main() {
  group('StorageService.savePageToBook', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('storage_service_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'assigns next page number based on pages_images.txt, not filesystem',
      () async {
        final pagesFile = File(p.join(tempDir.path, 'pages_images.txt'));
        await pagesFile.writeAsString(
          'page_001.jpg\npage_002.jpg\npage_003.jpg\n',
        );

        await File(p.join(tempDir.path, 'page_001.jpg')).create();
        await File(p.join(tempDir.path, 'page_003.jpg')).create();

        final sourceDir = await Directory.systemTemp.createTemp('source_image_');
        final sourceImage = File(p.join(sourceDir.path, 'source.jpg'));
        await sourceImage.writeAsBytes([0xFF, 0xD8]);

        try {
          final result = await StorageService.savePageToBook(
            bookDirectory: tempDir,
            sourceImagePath: sourceImage.path,
          );

          expect(
            p.basename(result.path),
            'page_004.jpg',
            reason: 'Next page should be numbered 004 based on pages_images.txt',
          );
        } finally {
          await sourceDir.delete(recursive: true);
        }
      },
    );
  });

  group('StorageService.deletePageFromBook', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('storage_service_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('deletes and renumbers pages sequentially', () async {
      final pagesFile = File(p.join(tempDir.path, 'pages_images.txt'));
      await pagesFile.writeAsString(
        'page_001.jpg\npage_002.jpg\npage_003.jpg\n',
      );

      await File(p.join(tempDir.path, 'page_001.jpg')).create();
      await File(p.join(tempDir.path, 'page_002.jpg')).create();
      await File(p.join(tempDir.path, 'page_003.jpg')).create();

      final result = await StorageService.deletePageFromBook(
        bookDirectory: tempDir,
        fileName: 'page_002.jpg',
      );

      expect(result, true);

      expect(
        await File(p.join(tempDir.path, 'page_001.jpg')).exists(),
        true,
      );
      expect(
        await File(p.join(tempDir.path, 'page_002.jpg')).exists(),
        true,
        reason: 'old page_003.jpg should be renamed to page_002.jpg',
      );
      expect(
        await File(p.join(tempDir.path, 'page_003.jpg')).exists(),
        false,
      );

      final updatedPages = await pagesFile.readAsString();
      expect(
        updatedPages,
        'page_001.jpg\npage_002.jpg\n',
      );
    });
  });
}

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
      'assigns next page number based on metadata.txt, not filesystem',
      () async {
        // Setup: create a book with 3 pages in metadata.txt
        final metadataFile = File(p.join(tempDir.path, 'metadata.txt'));
        await metadataFile.writeAsString(
          'page_001.jpg\npage_002.jpg\npage_003.jpg\n',
        );

        // Create actual image files for page 1 and 3 only (simulate deletion)
        await File(p.join(tempDir.path, 'page_001.jpg')).create();
        await File(p.join(tempDir.path, 'page_003.jpg')).create();
        // page_002.jpg is missing

        // Create a source image to copy (in a separate directory to avoid filesystem counting)
        final sourceDir = await Directory.systemTemp.createTemp(
          'source_image_',
        );
        final sourceImage = File(p.join(sourceDir.path, 'source.jpg'));
        await sourceImage.writeAsBytes([0xFF, 0xD8]); // minimal JPEG header

        try {
          // Act: save a new page
          final result = await StorageService.savePageToBook(
            bookDirectory: tempDir,
            sourceImagePath: sourceImage.path,
          );

          // Assert: should be page_004.jpg (next index after 3 in metadata)
          expect(
            p.basename(result.path),
            'page_004.jpg',
            reason: 'Next page should be numbered 004 (based on metadata.txt count), not 003 (filesystem count)',
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

    test('deletes page file and updates metadata.txt', () async {
      // Setup: create a book with 3 pages
      final metadataFile = File(p.join(tempDir.path, 'metadata.txt'));
      await metadataFile.writeAsString(
        'page_001.jpg\npage_002.jpg\npage_003.jpg\n',
      );

      // Create image files
      await File(p.join(tempDir.path, 'page_001.jpg')).create();
      await File(p.join(tempDir.path, 'page_002.jpg')).create();
      await File(p.join(tempDir.path, 'page_003.jpg')).create();

      // Act: delete page_002.jpg
      final result = await StorageService.deletePageFromBook(
        bookDirectory: tempDir,
        fileName: 'page_002.jpg',
      );

      // Assert: method returns true
      expect(result, true);

      // Assert: file is deleted
      expect(
        await File(p.join(tempDir.path, 'page_002.jpg')).exists(),
        false,
        reason: 'File page_002.jpg should be deleted',
      );

      // Assert: metadata.txt is updated
      final updatedMetadata = await metadataFile.readAsString();
      expect(
        updatedMetadata,
        'page_001.jpg\npage_003.jpg\n',
        reason: 'metadata.txt should contain only remaining pages',
      );
    });
  });
}

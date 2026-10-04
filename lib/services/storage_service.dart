// ignore_for_file: unintended_html_in_doc_comment

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/book_model.dart';

class StorageService {
  /// Returns the base directory for book projects: <app_dir>/books
  static Future<Directory> getBooksDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory(p.join(appDocDir.path, 'books'));

    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir;
  }

  /// Scans <app_dir>/books and returns all book directories as a list
  static Future<List<BookModel>> fetchAllBooks() async {
    final booksDir = await getBooksDirectory();
    final List<BookModel> books = [];

    if (!await booksDir.exists()) return books;

    final List<FileSystemEntity> entities = booksDir.listSync();

    for (final entity in entities) {
      if (entity is Directory) {
        final folderName = p.basename(entity.path);

        // Fetch image files inside the book folder
        final imageRegex = RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false);
        final files = entity
            .listSync()
            .whereType<File>()
            .where((f) => imageRegex.hasMatch(f.path))
            .toList();

        // Order comes from pages_images.txt; fall back to name for legacy books
        final order = await _readPageOrder(entity);
        files.sort((a, b) {
          final ia = order.indexOf(p.basename(a.path));
          final ib = order.indexOf(p.basename(b.path));
          if (ia == -1 || ib == -1) return a.path.compareTo(b.path);
          return ia.compareTo(ib);
        });

        final stat = await entity.stat();

        books.add(
          BookModel(
            name: folderName,
            directory: entity,
            pageFiles: files,
            lastModified: stat.modified,
          ),
        );
      }
    }

    // Sort books by most recently modified
    books.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return books;
  }

  static Future<List<String>> _readPageOrder(Directory bookDirectory) async {
    final pagesFile = File(p.join(bookDirectory.path, 'pages_images.txt'));
    if (!await pagesFile.exists()) return [];
    return (await pagesFile.readAsLines())
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Creates a unique book directory. Handles automatic renaming if the directory already exists.
  /// Example: "My Book" -> "My Book (1)" -> "My Book (2)"
  /// Creates metadata.txt with title (line 1) and authors (line 2).
  static Future<BookModel> createUniqueBookDirectory({
    required String folderName,
    required String title,
    required String authors,
  }) async {
    final booksDir = await getBooksDirectory();
    final sanitizedName = folderName.trim().isEmpty
        ? 'New Book'
        : folderName.trim();

    String candidateName = sanitizedName;
    Directory targetDir = Directory(p.join(booksDir.path, candidateName));
    int counter = 1;

    while (await targetDir.exists()) {
      candidateName = '$sanitizedName ($counter)';
      targetDir = Directory(p.join(booksDir.path, candidateName));
      counter++;
    }

    await targetDir.create(recursive: true);

    // Create metadata.txt with title and authors
    final metadataFile = File(p.join(targetDir.path, 'metadata.txt'));
    await metadataFile.writeAsString('$title\n$authors\n');

    return BookModel(
      name: candidateName,
      directory: targetDir,
      pageFiles: [],
      lastModified: DateTime.now(),
    );
  }

  /// Saves a scanned image file into the specific book folder
  static Future<File> savePageToBook({
    required Directory bookDirectory,
    required String sourceImagePath,
  }) async {
    final pagesFile = File(p.join(bookDirectory.path, 'pages_images.txt'));

    // Unique, order-independent name: the order lives only in pages_images.txt
    final targetPath = p.join(
      bookDirectory.path,
      'page_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );

    final sourceFile = File(sourceImagePath);
    final copiedFile = await sourceFile.copy(targetPath);

    // Append filename to pages_images.txt
    final fileName = p.basename(copiedFile.path);
    await pagesFile.writeAsString('$fileName\n', mode: FileMode.append);

    return copiedFile;
  }

  /// Deletes a page image from the book folder and renumbers remaining pages
  static Future<bool> deletePageFromBook({
    required Directory bookDirectory,
    required String fileName,
  }) async {
    try {
      // Delete the file
      final filePath = p.join(bookDirectory.path, fileName);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Read current pages_images.txt
      final pagesFile = File(p.join(bookDirectory.path, 'pages_images.txt'));
      if (!await pagesFile.exists()) {
        return true;
      }

      final lines = await pagesFile.readAsLines();
      final remaining = lines
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l != fileName)
          .toList();
      await pagesFile.writeAsString(
        remaining.isEmpty ? '' : '${remaining.join('\n')}\n',
      );

      return true;
    } catch (e) {
      debugPrint('Error deleting page: $e');
      return false;
    }
  }

  /// Deletes an entire book directory and all its contents
  static Future<bool> deleteBook({required Directory bookDirectory}) async {
    try {
      if (await bookDirectory.exists()) {
        await bookDirectory.delete(recursive: true);
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting book: $e');
      return false;
    }
  }
}

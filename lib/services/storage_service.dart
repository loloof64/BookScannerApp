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

        // Sort files by name (e.g., page_001.jpg, page_002.jpg)
        files.sort((a, b) => a.path.compareTo(b.path));

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

  /// Creates a unique book directory. Handles automatic renaming if the directory already exists.
  /// Example: "My Book" -> "My Book (1)" -> "My Book (2)"
  static Future<BookModel> createUniqueBookDirectory(
    String requestedTitle,
  ) async {
    final booksDir = await getBooksDirectory();
    final sanitizedTitle = requestedTitle.trim().isEmpty
        ? 'New Book'
        : requestedTitle.trim();

    String candidateName = sanitizedTitle;
    Directory targetDir = Directory(p.join(booksDir.path, candidateName));
    int counter = 1;

    while (await targetDir.exists()) {
      candidateName = '$sanitizedTitle ($counter)';
      targetDir = Directory(p.join(booksDir.path, candidateName));
      counter++;
    }

    await targetDir.create(recursive: true);

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
    final metadataFile = File(p.join(bookDirectory.path, 'metadata.txt'));
    int nextIndex = 1;

    if (await metadataFile.exists()) {
      try {
        final lines = await metadataFile.readAsLines();
        nextIndex = lines.where((line) => line.trim().isNotEmpty).length + 1;
      } catch (e) {
        debugPrint('Error reading metadata.txt: $e');
      }
    }

    final paddedIndex = nextIndex.toString().padLeft(3, '0');
    final targetPath = p.join(bookDirectory.path, 'page_$paddedIndex.jpg');

    final sourceFile = File(sourceImagePath);
    return await sourceFile.copy(targetPath);
  }
}

// ignore_for_file: unintended_html_in_doc_comment

import 'dart:io';

/// Represents a book project stored in the <app>/books directory
class BookModel {
  final String name;
  final Directory directory;
  final List<File> pageFiles;
  final DateTime lastModified;

  BookModel({
    required this.name,
    required this.directory,
    required this.pageFiles,
    required this.lastModified,
  });
}

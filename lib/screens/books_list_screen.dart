import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:book_scanner_app/screens/read_book_content_screen.dart';
import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../services/storage_service.dart';

class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  late Future<List<BookModel>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _refreshBooks();
  }

  void _refreshBooks() {
    setState(() {
      _booksFuture = StorageService.fetchAllBooks();
    });
  }

  Future<void> _showCreateBookDialog() async {
    final titleController = TextEditingController();
    final authorsController = TextEditingController();

    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Book'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: authorsController,
                decoration: const InputDecoration(
                  hintText: 'Authors',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final authors = authorsController.text.trim();
                Navigator.pop(context, {
                  'title': title.isEmpty ? 'New Book' : title,
                  'authors': authors,
                });
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      final folderName = result['title']!;
      final title = result['title']!;
      final authors = result['authors']!;
      await StorageService.createUniqueBookDirectory(
        folderName: folderName,
        title: title,
        authors: authors,
      );
      if (!mounted) return;
      _refreshBooks();
    }
  }

  void _showDeleteOptions(BookModel book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Delete "${book.name}" and all its contents?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _deleteBook(book),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBook(BookModel book) async {
    Navigator.pop(context);
    final success = await StorageService.deleteBook(
      bookDirectory: book.directory,
    );

    if (mounted) {
      if (success) {
        _refreshBooks();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete book')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Scanned Books'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshBooks),
        ],
      ),
      body: FutureBuilder<List<BookModel>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading books: ${snapshot.error}'),
            );
          }

          final books = snapshot.data ?? [];

          if (books.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No books found in <app>/books',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final coverFile = book.pageFiles.isNotEmpty
                  ? book.pageFiles.first
                  : null;

              return GestureDetector(
                onLongPress: () => _showDeleteOptions(book),
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 50,
                        height: 60,
                        color: Colors.grey[300],
                        child: coverFile != null
                            ? Image.file(coverFile, fit: BoxFit.cover)
                            : const Icon(Icons.book, color: Colors.grey),
                      ),
                    ),
                    title: FutureBuilder<String>(
                      future: () async {
                        final metadata = File(
                          p.join(book.directory.path, 'metadata.txt'),
                        );
                        if (await metadata.exists()) {
                          try {
                            final lines = await metadata.readAsLines();
                            if (lines.isNotEmpty && lines[0].trim().isNotEmpty) {
                              return lines[0].trim();
                            }
                          } catch (e) {
                            //
                          }
                        }
                        return book.name;
                      }(),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? book.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    subtitle: FutureBuilder<Map<String, dynamic>>(
                      future: () async {
                        final metadata = File(
                          p.join(book.directory.path, 'metadata.txt'),
                        );
                        final pagesFile = File(
                          p.join(book.directory.path, 'pages_images.txt'),
                        );

                        String authors = '';
                        if (await metadata.exists()) {
                          try {
                            final lines = await metadata.readAsLines();
                            if (lines.length > 1) {
                              authors = lines[1].trim();
                            }
                          } catch (e) {
                            //
                          }
                        }

                        int pageCount = book.pageFiles.length;
                        if (await pagesFile.exists()) {
                          try {
                            final lines = await pagesFile.readAsLines();
                            pageCount =
                                lines.where((line) => line.trim().isNotEmpty).length;
                          } catch (e) {
                            //
                          }
                        }

                        return {'authors': authors, 'pageCount': pageCount};
                      }(),
                      builder: (context, snapshot) {
                        final data = snapshot.data ?? {};
                        final authors = data['authors'] as String? ?? '';
                        final pageCount = data['pageCount'] as int? ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (authors.isNotEmpty)
                              Text(authors, style: const TextStyle(fontSize: 12)),
                            Text('$pageCount page(s)',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        );
                      },
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReadBookContent(book: book),
                        ),
                      );
                      _refreshBooks();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBookDialog,
        icon: const Icon(Icons.create_new_folder),
        label: const Text('New Book'),
      ),
    );
  }
}

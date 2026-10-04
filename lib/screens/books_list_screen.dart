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

  /// Dialog to prompt the user for a new book name
  Future<void> _showCreateBookDialog() async {
    final controller = TextEditingController();

    final String? bookTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Book'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Book name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(context, text.isEmpty ? 'New Book' : text);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (bookTitle != null && mounted) {
      // Create folder with unique name handling
      await StorageService.createUniqueBookDirectory(bookTitle);

      if (!mounted) return;

      // Refresh listing after returning
      _refreshBooks();
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

              return Card(
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
                  title: Text(
                    book.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: FutureBuilder<int>(
                    future: () async {
                      final metadata = File(
                        p.join(book.directory.path, 'metadata.txt'),
                      );
                      if (await metadata.exists()) {
                        try {
                          final lines = await metadata.readAsLines();
                          return lines
                              .where((line) => line.trim().isNotEmpty)
                              .length;
                        } catch (e) {
                          return book.pageFiles.length;
                        }
                      }
                      return book.pageFiles.length;
                    }(),
                    builder: (context, snapshot) {
                      final pageCount = snapshot.data ?? book.pageFiles.length;
                      return Text('$pageCount page(s)');
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

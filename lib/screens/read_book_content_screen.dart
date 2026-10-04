import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/book_model.dart';
import '../services/storage_service.dart';
import 'add_scan_to_book_screen.dart';

class ReadBookContent extends StatefulWidget {
  final BookModel book;

  const ReadBookContent({super.key, required this.book});

  @override
  State<ReadBookContent> createState() => _ReadBookContentState();
}

class _ReadBookContentState extends State<ReadBookContent> {
  List<String> imageFiles = [];
  late Future<List<String>> _imageFilesFuture;

  @override
  void initState() {
    super.initState();
    _loadImageFiles();
  }

  void _loadImageFiles() {
    setState(() {
      _imageFilesFuture = _fetchImageFiles();
    });
  }

  Future<List<String>> _fetchImageFiles() async {
    final List<String> files = [];

    final metadataFile = File(
      p.join(widget.book.directory.path, 'metadata.txt'),
    );

    if (await metadataFile.exists()) {
      try {
        final lines = await metadataFile.readAsLines();
        for (final line in lines) {
          final fileName = line.trim();
          if (fileName.isNotEmpty) {
            final file = File(p.join(widget.book.directory.path, fileName));
            if (await file.exists()) {
              files.add(fileName);
            }
          }
        }
      } catch (e) {
        debugPrint('Error reading metadata.txt: $e');
      }
    }

    if (files.isEmpty) {
      final dir = Directory(widget.book.directory.path);
      if (await dir.exists()) {
        final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif'];
        final entries = await dir.list().toList();

        for (final entry in entries) {
          if (entry is File) {
            final lowerPath = entry.path.toLowerCase();
            if (imageExtensions.any((ext) => lowerPath.endsWith(ext))) {
              files.add(entry.uri.pathSegments.last);
            }
          }
        }
      }
    }

    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadImageFiles,
          ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _imageFilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading images: ${snapshot.error}'),
            );
          }

          final imageFiles = snapshot.data ?? [];

          if (imageFiles.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No images found in this book',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
            ),
            itemCount: imageFiles.length,
            itemBuilder: (context, index) {
              final fileName = imageFiles[index];
              final file = File(p.join(widget.book.directory.path, fileName));

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImage(
                        imagePath: file.path,
                        fileName: fileName,
                        bookDirectory: widget.book.directory,
                        onImageDeleted: _loadImageFiles,
                      ),
                    ),
                  );
                },
                onLongPress: () => _showDeleteOptions(context, fileName),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, size: 40);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddScanToBookScreen(targetBook: widget.book),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteOptions(BuildContext context, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: Text('Delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _deleteImage(fileName),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteImage(String fileName) async {
    Navigator.pop(context);
    final success = await StorageService.deletePageFromBook(
      bookDirectory: widget.book.directory,
      fileName: fileName,
    );

    if (mounted) {
      if (success) {
        _loadImageFiles();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete image')),
        );
      }
    }
  }
}

class FullScreenImage extends StatelessWidget {
  final String imagePath;
  final String fileName;
  final Directory bookDirectory;
  final VoidCallback onImageDeleted;

  const FullScreenImage({
    super.key,
    required this.imagePath,
    required this.fileName,
    required this.bookDirectory,
    required this.onImageDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      body: InteractiveViewer(
        child: Image.file(
          File(imagePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.broken_image, size: 64));
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: Text('Delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _deleteImage(context),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteImage(BuildContext context) async {
    Navigator.pop(context);
    final success = await StorageService.deletePageFromBook(
      bookDirectory: bookDirectory,
      fileName: fileName,
    );

    if (context.mounted) {
      if (success) {
        onImageDeleted();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete image')),
        );
      }
    }
  }
}

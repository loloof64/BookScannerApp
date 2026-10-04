import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:opencv_dart/opencv_dart.dart' as cv;
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

    final pagesFile = File(
      p.join(widget.book.directory.path, 'pages_images.txt'),
    );

    if (await pagesFile.exists()) {
      try {
        final lines = await pagesFile.readAsLines();
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
        debugPrint('Error reading pages_images.txt: $e');
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

  Future<Map<String, String>> _loadBookMetadata() async {
    final metadataFile = File(
      p.join(widget.book.directory.path, 'metadata.txt'),
    );

    String title = widget.book.name;
    String authors = '';

    if (await metadataFile.exists()) {
      try {
        final lines = await metadataFile.readAsLines();
        if (lines.isNotEmpty && lines[0].trim().isNotEmpty) {
          title = lines[0].trim();
        }
        if (lines.length > 1 && lines[1].trim().isNotEmpty) {
          authors = lines[1].trim();
        }
      } catch (e) {
        debugPrint('Error reading metadata.txt: $e');
      }
    }

    return {'title': title, 'authors': authors};
  }

  /// Downscales (max 1800px) and re-encodes as JPEG q80 (~250 KB/page) so
  /// 400 pages stay around 100 MB in memory. Also bakes in EXIF rotation.
  Future<Uint8List> _compressPage(String path) async {
    final img = await cv.imreadAsync(path);
    cv.Mat? small;
    try {
      final longSide = img.width > img.height ? img.width : img.height;
      final scale = 1800 / longSide;
      if (scale < 1) {
        small = await cv.resizeAsync(
          img,
          ((img.width * scale).round(), (img.height * scale).round()),
          interpolation: cv.INTER_AREA,
        );
      }
      final (_, bytes) = await cv.imencodeAsync(
        '.jpg',
        small ?? img,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 80]),
      );
      return bytes;
    } finally {
      small?.dispose();
      img.dispose();
    }
  }

  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fileNames = await _fetchImageFiles();
      if (fileNames.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('No pages to export')));
        return;
      }

      final title = (await _loadBookMetadata())['title']!;
      final doc = pw.Document(title: title);
      final progress = ValueNotifier<int>(0);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: ValueListenableBuilder<int>(
              valueListenable: progress,
              builder: (_, done, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: done / fileNames.length),
                  const SizedBox(height: 12),
                  Text('Building PDF… $done / ${fileNames.length}'),
                ],
              ),
            ),
          ),
        ),
      );
      for (final name in fileNames) {
        final bytes = await _compressPage(p.join(widget.book.directory.path, name));
        progress.value++;
        doc.addPage(pw.Page(
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
        ));
      }

      final pdfBytes = await doc.save();
      if (mounted) Navigator.pop(context); // progress dialog
      final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = await FilePicker.saveFile(
        dialogTitle: 'Export PDF',
        fileName: '$safeTitle.pdf',
        bytes: pdfBytes,
      );
      if (path != null) {
        messenger.showSnackBar(const SnackBar(content: Text('PDF exported')));
      }
    } catch (e) {
      if (mounted) Navigator.popUntil(context, (r) => r is! PopupRoute);
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Map<String, String>>(
          future: _loadBookMetadata(),
          builder: (context, snapshot) {
            final title = snapshot.data?['title'] ?? widget.book.name;
            final authors = snapshot.data?['authors'] ?? '';

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title),
                if (authors.isNotEmpty)
                  Text(authors,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            );
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
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
                      ),
                    ),
                  );
                },
                onLongPress: () => _showImageOptions(
                  context,
                  fileName,
                  imageFiles,
                  index,
                ),
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
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddScanToBookScreen(targetBook: widget.book),
            ),
          );
          if (result == true) {
            _loadImageFiles();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showImageOptions(
    BuildContext context,
    String fileName,
    List<String> imageFiles,
    int currentIndex,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Image Options'),
        content: Text(fileName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (imageFiles.length > 1)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSwapDialog(context, currentIndex, imageFiles);
              },
              child: const Text('Swap with...'),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteImage(fileName);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSwapDialog(
    BuildContext context,
    int currentIndex,
    List<String> imageFiles,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select image to swap with'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
            ),
            itemCount: imageFiles.length,
            itemBuilder: (context, index) {
              if (index == currentIndex) {
                return GestureDetector(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.file(
                          File(p.join(
                            widget.book.directory.path,
                            imageFiles[index],
                          )),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.broken_image, size: 40);
                          },
                        ),
                        Container(
                          color: Colors.black45,
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _swapPages(currentIndex, index);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.file(
                    File(p.join(
                      widget.book.directory.path,
                      imageFiles[index],
                    )),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, size: 40);
                    },
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _swapPages(int index1, int index2) async {
    try {
      final pagesFile = File(
        p.join(widget.book.directory.path, 'pages_images.txt'),
      );

      if (!await pagesFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('pages_images.txt not found')),
        );
        return;
      }

      final lines = await pagesFile.readAsLines();
      if (index1 < lines.length && index2 < lines.length) {
        // Just swap the order in pages_images.txt, don't rename files
        final temp = lines[index1];
        lines[index1] = lines[index2];
        lines[index2] = temp;

        await pagesFile.writeAsString('${lines.join('\n')}\n');
        _loadImageFiles();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Images swapped')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error swapping pages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error swapping images: $e')),
        );
      }
    }
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

  const FullScreenImage({
    super.key,
    required this.imagePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        centerTitle: true,
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
}

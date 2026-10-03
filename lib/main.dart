import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'image_processor.dart'; // Import the image processor

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const BookScannerPage(),
    );
  }
}

class BookScannerPage extends StatefulWidget {
  const BookScannerPage({super.key});

  @override
  State<BookScannerPage> createState() => _BookScannerPageState();
}

class _BookScannerPageState extends State<BookScannerPage> {
  // Variable to store the selected image
  XFile? _selectedImage;

  // Variable to indicate if processing is in progress
  bool _isProcessing = false;

  // Variable to store the processed image
  XFile? _processedImage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _selectImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _processedImage = null;
      });
    }
  }

  Future<void> _selectImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _processedImage = null;
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    // Try to use document directory first
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final outputDir = Directory('${appDocDir.path}/scanned_photos');

      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
        debugPrint('Created output directory: ${outputDir.path}');
      }
    } catch (e) {
      // If that fails, try temporary directory as fallback
      try {
        final tempDir = Directory.systemTemp;
        final outputDir = Directory('${tempDir.path}/scanned_photos');

        if (!await outputDir.exists()) {
          await outputDir.create(recursive: true);
          debugPrint('Created temporary directory: ${outputDir.path}');
        }
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: unable to create directory for images'),
            ),
          );
        }
        debugPrint('Error creating directories: $e2');
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Actual processing using OpenCV
      final processedImagePath = await processBookImage(_selectedImage!.path);

      setState(() {
        _isProcessing = false;
        if (processedImagePath != null) {
          _processedImage = XFile(processedImagePath);
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error during processing: $e')));
      }
      debugPrint('Processing error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Scanner'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Buttons to select the image
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _selectImageFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('From Gallery'),
                ),
                ElevatedButton.icon(
                  onPressed: _selectImageFromCamera,
                  icon: const Icon(Icons.camera),
                  label: const Text('From Camera'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Display of the selected image
            if (_isProcessing)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_processedImage != null)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.file(
                    File(_processedImage!.path),
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else if (_selectedImage != null)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.file(
                    File(_selectedImage!.path),
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 64, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(
                        'No image selected',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Processing button
            if (_selectedImage != null)
              ElevatedButton.icon(
                onPressed: _processImage,
                icon: const Icon(Icons.autorenew),
                label: const Text('Process Image'),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

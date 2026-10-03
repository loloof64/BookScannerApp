import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_processor.dart';

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
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const BookScannerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BookScannerPage extends StatefulWidget {
  const BookScannerPage({super.key});

  @override
  State<BookScannerPage> createState() => _BookScannerPageState();
}

class _BookScannerPageState extends State<BookScannerPage> {
  XFile? _selectedImage;
  bool _isProcessing = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Actual processing using OpenCV
      final processedImagePath = await processBookImage(_selectedImage!.path);

      setState(() {
        _isProcessing = false;
        if (processedImagePath != null) {
          // Replace the original image with the processed one
          _selectedImage = XFile(processedImagePath);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image processed successfully!')),
            );
          }
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Scanner'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _pickImage),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedImage == null
                ? const Center(child: Text('No image selected'))
                : Image.file(File(_selectedImage!.path), fit: BoxFit.contain),
          ),
          if (_isProcessing)
            const LinearProgressIndicator()
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _processImage,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Process Image'),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  // Variable pour stocker l'image sélectionnée
  XFile? _selectedImage;

  // Variable pour indiquer si le traitement est en cours
  bool _isProcessing = false;

  // Variable pour stocker l'image traitée
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

    setState(() {
      _isProcessing = true;
    });

    // Simulate processing
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isProcessing = false;
      _processedImage =
          _selectedImage; // In a real app, this would be the result
    });
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
            // Boutons pour sélectionner l'image
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

            // Affichage de l'image sélectionnée
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

            // Bouton de traitement
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

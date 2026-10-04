import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/book_model.dart';
import '../services/storage_service.dart';
import 'crop_overlay_screen.dart';
import 'crop_preview_screen.dart';

class AddScanToBookScreen extends StatefulWidget {
  final BookModel
  targetBook; // Mandatory because a book is always created/selected before

  const AddScanToBookScreen({super.key, required this.targetBook});

  @override
  State<AddScanToBookScreen> createState() => _AddScanToBookScreenState();
}

class _AddScanToBookScreenState extends State<AddScanToBookScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _pickedImagePath;
  bool _isLoading = false;

  /// Pick an image from Camera or Gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (pickedFile == null) return;

      setState(() {
        _pickedImagePath = pickedFile.path;
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// Process the image and save it to book
  Future<void> _processAndSaveImage() async {
    if (_pickedImagePath == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Navigate to crop overlay screen for processing first
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CropOverlayScreen(imagePath: _pickedImagePath!),
        ),
      );

      if (result != null && result is List<Offset>) {
        setState(() => _isLoading = false);

        if (!mounted) return;

        // Show preview screen
        final processedImagePath = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CropPreviewScreen(
              imagePath: _pickedImagePath!,
              corners: result,
            ),
          ),
        );

        if (processedImagePath != null && processedImagePath is String) {
          // User confirmed crop, save the image
          await _saveImage(processedImagePath);
        } else {
          // User clicked Redo Crop, stay on this screen
          setState(() => _pickedImagePath = _pickedImagePath);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error processing image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error adding page: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Page to ${widget.targetBook.name}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_pickedImagePath != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Stack(
                        children: [
                          Image.file(
                            File(_pickedImagePath!),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          // Overlay with crop corners (simulated)
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white.withAlpha(
                                        (0.7 * 255).toInt(),
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Stack(
                                    children: [
                                      // Top left corner
                                      Positioned(
                                        top: 10,
                                        left: 10,
                                        child: Icon(
                                          Icons.crop_square,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      // Top right corner
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Icon(
                                          Icons.crop_square,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      // Bottom left corner
                                      Positioned(
                                        bottom: 10,
                                        left: 10,
                                        child: Icon(
                                          Icons.crop_square,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      // Bottom right corner
                                      Positioned(
                                        bottom: 10,
                                        right: 10,
                                        child: Icon(
                                          Icons.crop_square,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.photo_camera,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No image selected',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _pickImage(ImageSource.camera),
                        child: const Text('Camera'),
                      ),
                      ElevatedButton(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        child: const Text('Gallery'),
                      ),
                      if (_pickedImagePath != null)
                        ElevatedButton(
                          onPressed: _processAndSaveImage,
                          child: const Text('Crop page'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveImage(String imagePath) async {
    try {
      setState(() => _isLoading = true);

      await StorageService.savePageToBook(
        bookDirectory: widget.targetBook.directory,
        sourceImagePath: imagePath,
      );

      setState(() {
        _isLoading = false;
        _pickedImagePath = null;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Page added successfully!')));

      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error saving image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

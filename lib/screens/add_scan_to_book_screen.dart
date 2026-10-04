import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/book_model.dart';
import '../services/storage_service.dart';
import 'crop_overlay_screen.dart'; // Import the crop overlay screen

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
        // In a real implementation, this would:
        // 1. Correct perspective based on the corner points
        // 2. Crop to the document edges
        // 3. Enhance the image quality

        // For now, we'll just save the original image (in a real app you'd process it)
        final savedFile = await StorageService.savePageToBook(
          bookDirectory: widget.targetBook.directory,
          sourceImagePath: _pickedImagePath!,
        );

        // Update metadata.txt file with new image name
        final fileName = p.basename(savedFile.path);
        final metadataFile = File(
          p.join(widget.targetBook.directory.path, 'metadata.txt'),
        );

        // Create the metadata file if it doesn't exist
        if (!await metadataFile.exists()) {
          await metadataFile.create(recursive: true);
        }

        // Append the new filename to metadata.txt
        await metadataFile.writeAsString('$fileName\n', mode: FileMode.append);

        setState(() {
          _isLoading = false;
          _pickedImagePath = null;
        });

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page added successfully!')),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
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
                          child: const Text('Save Page'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

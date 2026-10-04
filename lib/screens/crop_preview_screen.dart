import 'dart:io';

import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../services/image_processor.dart';

class CropPreviewScreen extends StatefulWidget {
  final String imagePath;
  final List<Offset> corners;

  const CropPreviewScreen({
    super.key,
    required this.imagePath,
    required this.corners,
  });

  @override
  State<CropPreviewScreen> createState() => _CropPreviewScreenState();
}

class _CropPreviewScreenState extends State<CropPreviewScreen> {
  String? _processedImagePath;
  bool _isProcessing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  Future<void> _processImage() async {
    try {
      final originalImage = cv.imread(widget.imagePath);
      if (originalImage.isEmpty) {
        setState(() {
          _error = 'Failed to load image';
          _isProcessing = false;
        });
        return;
      }

      final imgWidth = originalImage.cols.toDouble();
      final imgHeight = originalImage.rows.toDouble();
      originalImage.dispose();

      const previewSize = 300.0;
      final scaledCorners = widget.corners
          .map((corner) => cv.Point2f(
                corner.dx * (imgWidth / previewSize),
                corner.dy * (imgHeight / previewSize),
              ))
          .toList();

      final result = await warpAndStraightenBook(
        widget.imagePath,
        customCorners: scaledCorners,
      );

      setState(() {
        _processedImagePath = result;
        _isProcessing = false;
        if (result == null) {
          _error = 'Failed to process image';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview Crop')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                )
              : _processedImagePath != null
                  ? Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Image.file(
                              File(_processedImagePath!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Redo Crop'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, _processedImagePath);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const Center(child: Text('No image to display')),
    );
  }
}

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:book_scanner_app/image_processor.dart';

void main() async {
  // Required before initializing native plugins or asynchronous code in main
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _processedImagePath;
  bool _isLoading = false;

  /// Pick an image from Camera or Gallery and trigger processing pipeline
  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
      });

      final String imagePath = pickedFile.path;

      // Load original dimensions using OpenCV
      final img = cv.imread(imagePath);
      if (img.isEmpty) {
        _showErrorSnackBar('Failed to load image with OpenCV.');
        return;
      }

      final double imgWidth = img.cols.toDouble();
      final double imgHeight = img.rows.toDouble();

      // Perform initial automatic corner detection
      final initialCorners = await detectCornersAuto(img, img.cols, img.rows);
      img.dispose();

      if (!mounted) return;

      // Navigate to Crop Overlay screen for user corner adjustment
      final List<cv.Point2f>? userValidatedCorners = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CropOverlayScreen(
            imagePath: imagePath,
            initialCorners: initialCorners,
            imageWidth: imgWidth,
            imageHeight: imgHeight,
          ),
        ),
      );

      if (userValidatedCorners != null && userValidatedCorners.length == 4) {
        // Execute perspective transformation using updated corners
        final String? resultPath = await warpAndStraightenBook(
          imagePath,
          customCorners: userValidatedCorners,
        );

        if (resultPath != null) {
          setState(() {
            _processedImagePath = resultPath;
          });
        } else {
          _showErrorSnackBar('Perspective transformation failed.');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error processing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Scanner'), centerTitle: true),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing image with OpenCV...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Display Area
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: _processedImagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_processedImagePath!),
                              fit: BoxFit.contain,
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.menu_book,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No image selected',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _pickAndProcessImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _pickAndProcessImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

/// Interactive screen allowing users to drag and adjust corners before warping
class CropOverlayScreen extends StatefulWidget {
  final String imagePath;
  final List<cv.Point2f> initialCorners;
  final double imageWidth;
  final double imageHeight;

  const CropOverlayScreen({
    super.key,
    required this.imagePath,
    required this.initialCorners,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  State<CropOverlayScreen> createState() => _CropOverlayScreenState();
}

class _CropOverlayScreenState extends State<CropOverlayScreen> {
  List<Offset>? displayCorners;
  double scale = 1.0;
  double offsetX = 0.0;
  double offsetY = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Book Corners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (displayCorners == null) return;

              // Map display coordinates back to original image resolution
              final realCorners = displayCorners!.map((p) {
                final realX = (p.dx - offsetX) / scale;
                final realY = (p.dy - offsetY) / scale;
                return cv.Point2f(
                  realX.clamp(0, widget.imageWidth),
                  realY.clamp(0, widget.imageHeight),
                );
              }).toList();

              Navigator.of(context).pop(realCorners);
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          // Calculate BoxFit.contain scale factor and margins
          final scaleX = screenWidth / widget.imageWidth;
          final scaleY = screenHeight / widget.imageHeight;
          scale = math.min(scaleX, scaleY);

          final displayedWidth = widget.imageWidth * scale;
          final displayedHeight = widget.imageHeight * scale;

          offsetX = (screenWidth - displayedWidth) / 2;
          offsetY = (screenHeight - displayedHeight) / 2;

          // Convert original points to screen coordinate space
          displayCorners ??= widget.initialCorners.map((p) {
            return Offset(p.x * scale + offsetX, p.y * scale + offsetY);
          }).toList();

          return Stack(
            children: [
              Positioned(
                left: offsetX,
                top: offsetY,
                width: displayedWidth,
                height: displayedHeight,
                child: Image.file(File(widget.imagePath), fit: BoxFit.fill),
              ),
              // Polygon overlay
              CustomPaint(
                size: Size(screenWidth, screenHeight),
                painter: QuadrilateralPainter(corners: displayCorners!),
              ),
              // 4 Interactive handles
              for (int i = 0; i < 4; i++)
                Positioned(
                  left: displayCorners![i].dx - 22,
                  top: displayCorners![i].dy - 22,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        displayCorners![i] = Offset(
                          (displayCorners![i].dx + details.delta.dx).clamp(
                            offsetX,
                            offsetX + displayedWidth,
                          ),
                          (displayCorners![i].dy + details.delta.dy).clamp(
                            offsetY,
                            offsetY + displayedHeight,
                          ),
                        );
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue,
                        child: CircleAvatar(
                          radius: 7,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Custom painter to draw bounding polygon and border lines
class QuadrilateralPainter extends CustomPainter {
  final List<Offset> corners;

  QuadrilateralPainter({required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.blue.withAlpha(80)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant QuadrilateralPainter oldDelegate) => true;
}

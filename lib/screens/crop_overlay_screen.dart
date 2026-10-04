import 'dart:io';

import 'package:flutter/material.dart';

class CropOverlayScreen extends StatefulWidget {
  final String imagePath;

  const CropOverlayScreen({super.key, required this.imagePath});

  @override
  State<CropOverlayScreen> createState() => _CropOverlayScreenState();
}

class _CropOverlayScreenState extends State<CropOverlayScreen> {
  // Default corners (could be adjusted based on image analysis)
  List<Offset> corners = [
    Offset(50, 50), // Top-left
    Offset(300, 50), // Top-right
    Offset(300, 300), // Bottom-right
    Offset(50, 300), // Bottom-left
  ];

  // Variables for dragging
  bool isDragging = false;
  int? draggingCornerIndex;
  Offset dragStartOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Crop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              // Process the cropped image and save it to a book
              try {
                // In a real implementation, you would process the image here
                // For now we'll just return to add_scan_to_book_screen
                Navigator.of(context).pop(corners);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to process image')),
                );
              }
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTapDown: (details) {
          // Handle tap to select a corner
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 300,
                width: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  image: DecorationImage(
                    image: FileImage(File(widget.imagePath)),
                    fit: BoxFit.contain,
                  ),
                ),
                child: Stack(
                  children: [
                    // Overlay to show crop area
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.blue.withAlpha((0.5 * 255).toInt()),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Draw the crop area polygon
                    CustomPaint(
                      size: const Size(300, 300),
                      painter: CropAreaPainter(corners),
                    ),
                    // Draggable corner indicators
                    for (int i = 0; i < corners.length; i++)
                      Positioned(
                        left: corners[i].dx - 16,
                        top: corners[i].dy - 16,
                        child: GestureDetector(
                          onTapDown: (details) {
                            setState(() {
                              draggingCornerIndex = i;
                              isDragging = true;
                              dragStartOffset = details.localPosition;
                            });
                          },
                          onPanUpdate: (details) {
                            if (draggingCornerIndex != null) {
                              setState(() {
                                Offset newOffset = corners[draggingCornerIndex!]
                                    .translate(
                                      details.delta.dx,
                                      details.delta.dy,
                                    );

                                // Boundary checks - ensure corners don't go outside the image
                                newOffset = Offset(
                                  newOffset.dx.clamp(0, 300),
                                  newOffset.dy.clamp(0, 300),
                                );

                                corners[draggingCornerIndex!] = newOffset;
                              });
                            }
                          },
                          onPanEnd: (details) {
                            setState(() {
                              isDragging = false;
                              draggingCornerIndex = null;
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.drag_indicator,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Drag the corners to adjust crop area'),
            ],
          ),
        ),
      ),
    );
  }
}

class CropAreaPainter extends CustomPainter {
  final List<Offset> corners;

  CropAreaPainter(this.corners);

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 4) return;

    // Create a path for the crop area
    Path path = Path();
    path.moveTo(corners[0].dx, corners[0].dy);
    path.lineTo(corners[1].dx, corners[1].dy);
    path.lineTo(corners[2].dx, corners[2].dy);
    path.lineTo(corners[3].dx, corners[3].dy);
    path.close();

    // Paint the crop area with semi-transparent blue
    Paint paint = Paint()
      ..color = Colors.blue.withAlpha(50)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Draw border around crop area
    Paint borderPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

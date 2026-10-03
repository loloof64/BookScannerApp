import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path/path.dart' as p;

/// Process an image to improve its quality using OpenCV.
Future<String?> processBookImage(String imagePath) async {
  cv.Mat? img;
  cv.Mat? gray;
  cv.Mat? blurred;
  cv.Mat? edged;
  cv.Mat? gaussian;
  cv.Mat? sharpened;
  cv.VecVecPoint? contours;

  try {
    // 1. Read the image
    img = cv.imread(imagePath);
    if (img.isEmpty) return null;

    // 2. Convert to grayscale
    gray = await cv.cvtColorAsync(img, cv.COLOR_BGR2GRAY);

    // 3. Apply Gaussian blur to reduce noise
    blurred = await cv.gaussianBlurAsync(gray, (5, 5), 0);

    // 4. Apply Canny edge detection
    edged = await cv.cannyAsync(blurred, 75, 200);

    // 5. Find contours
    final (foundContours, _) = cv.findContours(
      edged,
      cv.RETR_LIST,
      cv.CHAIN_APPROX_SIMPLE,
    );
    contours = foundContours;

    // 6. Draw the largest contour in red
    int largestIndex = -1;
    double maxArea = 0;

    if (contours.isNotEmpty) {
      for (int i = 0; i < contours.length; i++) {
        final area = cv.contourArea(contours[i]);
        if (area > maxArea) {
          maxArea = area;
          largestIndex = i;
        }
      }

      if (largestIndex != -1) {
        // Draw the contour in red with thickness 3
        cv.drawContours(
          img,
          contours,
          largestIndex,
          cv.Scalar.red,
          thickness: 3,
        );
      }
    }

    // 7. Enhance contrast and brightness for better visibility
    // Apply adaptive threshold to make it more like a scanned document
    final enhanced = await cv.adaptiveThresholdAsync(
      gray,
      255,
      cv.ADAPTIVE_THRESH_GAUSSIAN_C,
      cv.THRESH_BINARY,
      11,
      2,
    );

    // 8. Sharpen the image with stronger effect
    gaussian = await cv.gaussianBlurAsync(enhanced, (0, 0), 3);
    sharpened = await cv.addWeightedAsync(enhanced, 1.5, gaussian, -0.5, 0);

    // 9. Save to a new file
    final directory = p.dirname(imagePath);
    final filename = p.basenameWithoutExtension(imagePath);
    final outputPath = p.join(directory, '${filename}_processed.jpg');

    cv.imwrite(outputPath, sharpened);

    return outputPath;
  } catch (e) {
    debugPrint('Error during OpenCV processing: $e');
    return null;
  } finally {
    // Proper memory cleanup
    img?.dispose();
    gray?.dispose();
    blurred?.dispose();
    edged?.dispose();
    gaussian?.dispose();
    sharpened?.dispose();
    contours?.dispose();
  }
}

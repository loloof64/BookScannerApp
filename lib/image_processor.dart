import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// Process an image to improve its quality and detect the book's contours.
/// Returns the path of the processed image.
Future<String?> processBookImage(String imagePath) async {
  try {
    // 1. Read the image
    final img = cv.imread(imagePath);
    if (img.isEmpty) return null;

    // 2. Convert to grayscale
    final gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY);

    // 3. Apply Gaussian blur to reduce noise
    final blurred = cv.gaussianBlur(gray, (5, 5), 0);

    // 4. Contour detection (Canny)
    final edged = cv.canny(blurred, 75, 200);

    // 5. Find contours
    final (contours, _) = cv.findContours(
      edged,
      cv.RETR_LIST,
      cv.CHAIN_APPROX_SIMPLE,
    );

    // Find the largest contour (assumed to be the book page/cover)
    cv.VecPoint? largestContour;
    double maxArea = 0;
    for (int i = 0; i < contours.length; i++) {
      final contour = contours[i];
      final area = cv.contourArea(contour);
      if (area > maxArea) {
        maxArea = area;
        largestContour = contour;
      }
    }

    // Draw the detected contour in red on the image
    if (largestContour != null) {
      final contoursVec = cv.VecVecPoint();
      contoursVec.add(largestContour);
      cv.drawContours(img, contoursVec, 0, cv.Scalar.red, thickness: 3);
      contoursVec.dispose();
    }

    // 6. Sharpening improvement (Unsharp masking)
    final gaussian = cv.gaussianBlur(img, (0, 0), 3);
    final sharpened = cv.addWeighted(img, 1.5, gaussian, -0.5, 0);

    // 7. Save the processed image
    final outputPath = '${imagePath}_processed.jpg';
    cv.imwrite(outputPath, sharpened);

    // Free memory resources
    img.dispose();
    gray.dispose();
    blurred.dispose();
    edged.dispose();
    for (final c in contours) {
      c.dispose();
    }
    sharpened.dispose();
    gaussian.dispose();

    return outputPath;
  } catch (e) {
    debugPrint('Error during OpenCV processing: $e');
    return null;
  }
}

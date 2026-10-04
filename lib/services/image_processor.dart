import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path/path.dart' as p;

/// Warps, straightens, and applies targeted side-trimming based on actual boundaries.
Future<String?> processBookImage(String imagePath) async {
  cv.Mat? img;
  cv.Mat? gray;
  cv.Mat? blurred;
  cv.Mat? thresh;
  cv.Mat? edged;
  cv.Mat? kernel;
  cv.Mat? warpMatrix;
  cv.Mat? warpedColor;
  cv.Mat? croppedResult;
  cv.Mat? enhancedColor;
  cv.Mat? gaussian;
  cv.Mat? finalResult;

  try {
    // 1. Read original color image
    img = cv.imread(imagePath);
    if (img.isEmpty) return null;

    final originalWidth = img.cols;
    final originalHeight = img.rows;

    // 2. Grayscale & Blur
    gray = await cv.cvtColorAsync(img, cv.COLOR_BGR2GRAY);
    blurred = await cv.gaussianBlurAsync(gray, (9, 9), 0);

    // 3. Morphological Gradient: catches subtle paper-to-background contrast
    kernel = cv.getStructuringElement(cv.MORPH_RECT, (5, 5));
    final gradient = await cv.morphologyExAsync(
      blurred,
      cv.MORPH_GRADIENT,
      kernel,
    );

    // 4. Otsu Thresholding on Gradient
    final (_, thresholdMat) = await cv.thresholdAsync(
      gradient,
      0,
      255,
      cv.THRESH_BINARY + cv.THRESH_OTSU,
    );
    thresh = thresholdMat;
    gradient.dispose();

    // 5. Canny Edge Detection
    edged = await cv.cannyAsync(thresh, 50, 150);

    // 6. Find Contours
    final (contours, _) = await cv.findContoursAsync(
      edged,
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );

    List<cv.Point2f>? bestCorners;
    double maxArea = 0;
    final totalArea = originalWidth * originalHeight;

    for (int i = 0; i < contours.length; i++) {
      final contour = contours[i];
      final area = cv.contourArea(contour);

      if (area < totalArea * 0.15 ||
          area > totalArea * 0.92 ||
          area <= maxArea) {
        continue;
      }

      final minRect = cv.minAreaRect(contour);
      final pts = minRect.points
          .map((p) => cv.Point2f(p.x.toDouble(), p.y.toDouble()))
          .toList();

      if (pts.length == 4) {
        maxArea = area;
        bestCorners = _orderPointsSumDiff(pts);
      }
    }

    // 7. Fallback with safe defaults
    bestCorners ??= _orderPointsSumDiff([
      cv.Point2f(originalWidth * 0.05, originalHeight * 0.03),
      cv.Point2f(originalWidth * 0.95, originalHeight * 0.03),
      cv.Point2f(originalWidth * 0.95, originalHeight * 0.97),
      cv.Point2f(originalWidth * 0.05, originalHeight * 0.97),
    ]);

    final srcPoints = cv.VecPoint2f.fromList(bestCorners);

    // 8. Target dimensions
    final ptTL = bestCorners[0];
    final ptTR = bestCorners[1];
    final ptBR = bestCorners[2];
    final ptBL = bestCorners[3];

    final widthA = _distance(ptBR, ptBL);
    final widthB = _distance(ptTR, ptTL);
    final maxWidth = math.max(widthA, widthB).toDouble();

    final heightA = _distance(ptTR, ptBR);
    final heightB = _distance(ptTL, ptBL);
    final maxHeight = math.max(heightA, heightB).toDouble();

    final dstPoints = cv.VecPoint2f.fromList([
      cv.Point2f(0, 0),
      cv.Point2f(maxWidth - 1, 0),
      cv.Point2f(maxWidth - 1, maxHeight - 1),
      cv.Point2f(0, maxHeight - 1),
    ]);

    // 9. Warp perspective
    warpMatrix = cv.getPerspectiveTransform2f(srcPoints, dstPoints);
    warpedColor = await cv.warpPerspectiveAsync(img, warpMatrix, (
      maxWidth.toInt(),
      maxHeight.toInt(),
    ));

    // 10. Fine-tuned side trimming based on your feedback:
    // - Bottom: intact (0%)
    // - Top: light trim (1.5%)
    // - Left: moderate trim (3%)
    // - Right: targeted trim (8%)
    final cropLeft = (warpedColor.cols * 0.03).toInt();
    final cropRight = (warpedColor.cols * 0.08).toInt();
    final cropTop = (warpedColor.rows * 0.015).toInt();
    final cropBottom = 0;

    final cropWidth = math.max(1, warpedColor.cols - cropLeft - cropRight);
    final cropHeight = math.max(1, warpedColor.rows - cropTop - cropBottom);

    final roi = cv.Rect(cropLeft, cropTop, cropWidth, cropHeight);
    croppedResult = warpedColor.region(roi);

    // 11. Contrast & Brightness Enhancement
    enhancedColor = await cv.convertScaleAbsAsync(
      croppedResult,
      alpha: 1.10,
      beta: 5,
    );

    // 12. Sharpening
    gaussian = await cv.gaussianBlurAsync(enhancedColor, (0, 0), 3);
    finalResult = await cv.addWeightedAsync(
      enhancedColor,
      1.20,
      gaussian,
      -0.20,
      0,
    );

    // 13. Save output image
    final directory = p.dirname(imagePath);
    final filename = p.basenameWithoutExtension(imagePath);
    final outputPath = p.join(directory, '${filename}_warped.jpg');

    await cv.imwriteAsync(outputPath, finalResult);

    return outputPath;
  } catch (e, stack) {
    debugPrint('Error during perspective warp: $e\n$stack');
    return null;
  } finally {
    img?.dispose();
    gray?.dispose();
    blurred?.dispose();
    thresh?.dispose();
    edged?.dispose();
    kernel?.dispose();
    warpMatrix?.dispose();
    warpedColor?.dispose();
    croppedResult?.dispose();
    enhancedColor?.dispose();
    gaussian?.dispose();
    finalResult?.dispose();
  }
}

/// Precise coordinate Sum & Difference ordering (TL, TR, BR, BL)
List<cv.Point2f> _orderPointsSumDiff(List<cv.Point2f> pts) {
  if (pts.length != 4) return pts;

  cv.Point2f tl = pts[0];
  cv.Point2f tr = pts[0];
  cv.Point2f br = pts[0];
  cv.Point2f bl = pts[0];

  double minSum = double.infinity;
  double maxSum = -double.infinity;
  double minDiff = double.infinity;
  double maxDiff = -double.infinity;

  for (final p in pts) {
    final sum = p.x + p.y;
    final diff = p.y - p.x;

    if (sum < minSum) {
      minSum = sum;
      tl = p;
    }
    if (sum > maxSum) {
      maxSum = sum;
      br = p;
    }
    if (diff < minDiff) {
      minDiff = diff;
      tr = p;
    }
    if (diff > maxDiff) {
      maxDiff = diff;
      bl = p;
    }
  }

  return [tl, tr, br, bl];
}

/// Computes Euclidean distance between two 2D points.
double _distance(cv.Point2f p1, cv.Point2f p2) {
  final dx = p1.x - p2.x;
  final dy = p1.y - p2.y;
  return math.sqrt(dx * dx + dy * dy);
}

/// Dynamic automatic corner detection using OpenCV
Future<List<cv.Point2f>> detectCornersAuto(
  cv.Mat img,
  int width,
  int height,
) async {
  cv.Mat? gray;
  cv.Mat? blurred;
  cv.Mat? thresh;
  cv.Mat? edged;
  cv.Mat? kernel;

  try {
    gray = await cv.cvtColorAsync(img, cv.COLOR_BGR2GRAY);
    blurred = await cv.gaussianBlurAsync(gray, (9, 9), 0);

    kernel = cv.getStructuringElement(cv.MORPH_RECT, (5, 5));
    final gradient = await cv.morphologyExAsync(
      blurred,
      cv.MORPH_GRADIENT,
      kernel,
    );

    final (_, thresholdMat) = await cv.thresholdAsync(
      gradient,
      0,
      255,
      cv.THRESH_BINARY + cv.THRESH_OTSU,
    );
    thresh = thresholdMat;
    gradient.dispose();

    edged = await cv.cannyAsync(thresh, 50, 150);

    final (contours, _) = await cv.findContoursAsync(
      edged,
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );

    double maxArea = 0;
    final totalArea = (width * height).toDouble();
    List<cv.Point2f>? best;

    for (int i = 0; i < contours.length; i++) {
      final contour = contours[i];
      final area = cv.contourArea(contour);

      if (area < totalArea * 0.15 ||
          area > totalArea * 0.95 ||
          area <= maxArea) {
        continue;
      }

      final minRect = cv.minAreaRect(contour);
      final pts = minRect.points
          .map((p) => cv.Point2f(p.x.toDouble(), p.y.toDouble()))
          .toList();

      if (pts.length == 4) {
        maxArea = area;
        best = _orderPointsSumDiff(pts);
      }
    }

    return best ??
        _orderPointsSumDiff([
          cv.Point2f(width * 0.05, height * 0.03),
          cv.Point2f(width * 0.95, height * 0.03),
          cv.Point2f(width * 0.95, height * 0.97),
          cv.Point2f(width * 0.05, height * 0.97),
        ]);
  } finally {
    gray?.dispose();
    blurred?.dispose();
    thresh?.dispose();
    edged?.dispose();
    kernel?.dispose();
  }
}

/// Perform warp perspective transformation and contrast adjustment
Future<String?> warpAndStraightenBook(
  String imagePath, {
  required List<cv.Point2f> customCorners,
}) async {
  cv.Mat? img;
  cv.Mat? warpMatrix;
  cv.Mat? warpedColor;
  cv.Mat? enhancedColor;
  cv.Mat? gaussian;
  cv.Mat? finalResult;

  try {
    img = cv.imread(imagePath);
    if (img.isEmpty) return null;

    final srcPoints = cv.VecPoint2f.fromList(customCorners);

    final ptTL = customCorners[0];
    final ptTR = customCorners[1];
    final ptBR = customCorners[2];
    final ptBL = customCorners[3];

    final widthA = _distance(ptBR, ptBL);
    final widthB = _distance(ptTR, ptTL);
    final maxWidth = math.max(widthA, widthB).toDouble();

    final heightA = _distance(ptTR, ptBR);
    final heightB = _distance(ptTL, ptBL);
    final maxHeight = math.max(heightA, heightB).toDouble();

    final dstPoints = cv.VecPoint2f.fromList([
      cv.Point2f(0, 0),
      cv.Point2f(maxWidth - 1, 0),
      cv.Point2f(maxWidth - 1, maxHeight - 1),
      cv.Point2f(0, maxHeight - 1),
    ]);

    warpMatrix = cv.getPerspectiveTransform2f(srcPoints, dstPoints);
    warpedColor = await cv.warpPerspectiveAsync(img, warpMatrix, (
      maxWidth.toInt(),
      maxHeight.toInt(),
    ));

    // Apply contrast correction and unsharp mask
    enhancedColor = await cv.convertScaleAbsAsync(
      warpedColor,
      alpha: 1.10,
      beta: 5,
    );

    gaussian = await cv.gaussianBlurAsync(enhancedColor, (0, 0), 3);
    finalResult = await cv.addWeightedAsync(
      enhancedColor,
      1.20,
      gaussian,
      -0.20,
      0,
    );

    final directory = p.dirname(imagePath);
    final filename = p.basenameWithoutExtension(imagePath);
    final outputPath = p.join(directory, '${filename}_warped.jpg');

    await cv.imwriteAsync(outputPath, finalResult);

    return outputPath;
  } catch (e) {
    debugPrint('Perspective transformation error: $e');
    return null;
  } finally {
    img?.dispose();
    warpMatrix?.dispose();
    warpedColor?.dispose();
    enhancedColor?.dispose();
    gaussian?.dispose();
    finalResult?.dispose();
  }
}

/// Order 4 corner points consistently: [Top-Left, Top-Right, Bottom-Right, Bottom-Left]
List<cv.Point2f> orderPointsSumDiff(List<cv.Point2f> pts) {
  if (pts.length != 4) return pts;

  cv.Point2f tl = pts[0];
  cv.Point2f tr = pts[0];
  cv.Point2f br = pts[0];
  cv.Point2f bl = pts[0];

  double minSum = double.infinity;
  double maxSum = -double.infinity;
  double minDiff = double.infinity;
  double maxDiff = -double.infinity;

  for (final p in pts) {
    final sum = p.x + p.y;
    final diff = p.y - p.x;

    if (sum < minSum) {
      minSum = sum;
      tl = p;
    }
    if (sum > maxSum) {
      maxSum = sum;
      br = p;
    }
    if (diff < minDiff) {
      minDiff = diff;
      tr = p;
    }
    if (diff > maxDiff) {
      maxDiff = diff;
      bl = p;
    }
  }

  return [tl, tr, br, bl];
}

/// Compute Euclidean distance between two points
double distance(cv.Point2f p1, cv.Point2f p2) {
  final dx = p1.x - p2.x;
  final dy = p1.y - p2.y;
  return math.sqrt(dx * dx + dy * dy);
}

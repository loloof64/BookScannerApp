import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path/path.dart' as p;

/// Process an image to improve its quality and detect the book's contours.
/// Returns the path of the processed image.
Future<String?> processBookImage(String imagePath) async {
  cv.Mat? img;
  cv.Mat? gray;
  cv.Mat? blurred;
  cv.Mat? edged;
  cv.Mat? gaussian;
  cv.Mat? sharpened;
  cv.VecVecPoint? contours;

  try {
    // 1. Lecture de l'image
    img = cv.imread(imagePath);
    if (img.isEmpty) return null;

    // 2. Conversion en niveaux de gris (Async pour la fluidité)
    gray = await cv.cvtColorAsync(img, cv.COLOR_BGR2GRAY);

    // 3. Flou gaussien
    blurred = await cv.gaussianBlurAsync(gray, (5, 5), 0);

    // 4. Détection de contours (Canny)
    edged = await cv.cannyAsync(blurred, 75, 200);

    // 5. Recherche des contours
    final (foundContours, _) = cv.findContours(
      edged,
      cv.RETR_LIST,
      cv.CHAIN_APPROX_SIMPLE,
    );
    contours = foundContours;

    // Trouver l'index du plus grand contour
    int largestIndex = -1;
    double maxArea = 0;

    for (int i = 0; i < contours.length; i++) {
      final area = cv.contourArea(contours[i]);
      if (area > maxArea) {
        maxArea = area;
        largestIndex = i;
      }
    }

    // Dessiner le plus grand contour directement en utilisant son index
    // Cela évite de créer un nouveau vecteur et règle l'erreur "Unmodifiable Vec"
    if (largestIndex != -1) {
      cv.drawContours(img, contours, largestIndex, cv.Scalar.red, thickness: 3);
    }

    // 6. Amélioration de la netteté (Unsharp masking)
    gaussian = await cv.gaussianBlurAsync(img, (0, 0), 3);
    sharpened = await cv.addWeightedAsync(img, 1.5, gaussian, -0.5, 0);

    // 7. Sauvegarde de l'image traitée
    final directory = p.dirname(imagePath);
    final filename = p.basenameWithoutExtension(imagePath);
    final outputPath = p.join(directory, '${filename}_processed.jpg');

    cv.imwrite(outputPath, sharpened);

    return outputPath;
  } catch (e, stack) {
    debugPrint('Error during OpenCV processing: $e');
    debugPrint(stack.toString());
    return null;
  } finally {
    // Libération systématique de la mémoire native
    img?.dispose();
    gray?.dispose();
    blurred?.dispose();
    edged?.dispose();
    gaussian?.dispose();
    sharpened?.dispose();
    contours?.dispose(); // Libère tous les contours à l'intérieur d'un coup
  }
}

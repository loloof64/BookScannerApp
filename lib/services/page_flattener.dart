import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path/path.dart' as p;

const _smallWidth = 400;

/// Horizontal stretch factor per profile column (≥ 1, capped at 1.5).
///
/// [profile] is the paper brightness per column. Near the gutter the page curves
/// away from the camera: darker (cos θ) and horizontally compressed by 1/cos θ,
/// so each column is stretched by 1/(brightness / flat-page brightness).
/// ponytail: shape-from-shading on one axis only, assumes a cylinder and even lighting.
List<double> stretchWeights(List<double> profile) {
  final n = profile.length;
  final win = math.max(3, n ~/ 20);
  final smooth = List<double>.generate(n, (i) {
    var sum = 0.0, cnt = 0;
    for (var j = math.max(0, i - win); j <= math.min(n - 1, i + win); j++) {
      sum += profile[j];
      cnt++;
    }
    return sum / cnt;
  });
  final sorted = [...smooth]..sort();
  final ref = sorted[(n * 0.9).floor().clamp(0, n - 1)];
  return [for (final b in smooth) 1 / (b / ref).clamp(0.67, 1.0)];
}

/// Output width after stretching a [srcWidth]-px page.
int unrolledWidth(List<double> weights, int srcWidth) =>
    (srcWidth * weights.reduce((a, b) => a + b) / weights.length).round();

/// For each output column, the (fractional) source column to sample.
List<double> unrollColumns(List<double> weights, int srcWidth, int outWidth) {
  final n = weights.length;
  final u = List<double>.filled(n + 1, 0);
  for (var i = 0; i < n; i++) {
    u[i + 1] = u[i] + weights[i];
  }
  final scale = srcWidth / n;
  final out = List<double>.filled(outWidth, 0);
  var i = 0;
  for (var j = 0; j < outWidth; j++) {
    final t = (j + 0.5) * u[n] / outWidth;
    while (i < n - 1 && u[i + 1] <= t) {
      i++;
    }
    final src = (i + (t - u[i]) / weights[i]) * scale;
    out[j] = src.clamp(0, srcWidth - 1).toDouble();
  }
  return out;
}

/// Small blurred copy of the page with the text removed (≈ paper colour + lighting).
Future<cv.Mat> _paperSmall(cv.Mat src) async {
  final h = math.max(1, src.rows * _smallWidth ~/ src.cols);
  final small = await cv.resizeAsync(
    src,
    (_smallWidth, h),
    interpolation: cv.INTER_AREA,
  );
  final kernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, (15, 15));
  final noText = await cv.dilateAsync(small, kernel); // dark text vanishes
  final blurred = await cv.gaussianBlurAsync(noText, (0, 0), 8);
  small.dispose();
  kernel.dispose();
  noText.dispose();
  return blurred;
}

/// Unrolls the gutter curvature, flattens the lighting, and saves `<name>_flat.jpg`.
Future<String?> flattenPage(String imagePath) async {
  cv.Mat? img;
  cv.Mat? paper;
  cv.Mat? unrolled;
  cv.Mat? paper2;
  cv.Mat? background;
  cv.Mat? flat;

  try {
    img = await cv.imreadAsync(imagePath);
    if (img.isEmpty) return null;

    // 1. Geometry: horizontal stretch driven by the brightness profile
    paper = await _paperSmall(img);
    final gray = await cv.cvtColorAsync(paper, cv.COLOR_BGR2GRAY);
    final row = await cv.resizeAsync(
      gray,
      (_smallWidth, 1),
      interpolation: cv.INTER_AREA,
    );
    final profile = row.data.map((v) => v.toDouble()).toList();
    gray.dispose();
    row.dispose();

    final weights = stretchWeights(profile);
    final outWidth = unrolledWidth(weights, img.cols);
    final cols = unrollColumns(weights, img.cols, outWidth);

    final mapX = cv.Mat.fromList(1, outWidth, cv.MatType.CV_32FC1, cols);
    final mapXFull = await cv.repeatAsync(mapX, img.rows, 1);
    final mapY = cv.Mat.fromList(
      img.rows,
      1,
      cv.MatType.CV_32FC1,
      List<double>.generate(img.rows, (y) => y.toDouble()),
    );
    final mapYFull = await cv.repeatAsync(mapY, 1, outWidth);
    unrolled = await cv.remapAsync(
      img,
      mapXFull,
      mapYFull,
      cv.INTER_LANCZOS4, // stretching blurs, keep it as sharp as possible
      borderMode: cv.BORDER_REPLICATE,
    );
    for (final m in [mapX, mapXFull, mapY, mapYFull]) {
      m.dispose();
    }
    debugPrint('flattenPage: ${img.cols}px -> ${outWidth}px');

    // 2. Lighting: divide by the text-free paper estimate
    paper2 = await _paperSmall(unrolled);
    background = await cv.resizeAsync(paper2, (unrolled.cols, unrolled.rows));
    final divided = await cv.divideAsync(unrolled, background, scale: 255);

    // 3. Unsharp mask to win back the sharpness lost where columns were stretched
    final soft = await cv.gaussianBlurAsync(divided, (0, 0), 2);
    flat = await cv.addWeightedAsync(divided, 1.8, soft, -0.8, 0);
    divided.dispose();
    soft.dispose();

    final outputPath = p.join(
      p.dirname(imagePath),
      '${p.basenameWithoutExtension(imagePath)}_flat.jpg',
    );
    await cv.imwriteAsync(outputPath, flat);
    return outputPath;
  } catch (e, stack) {
    debugPrint('flattenPage error: $e\n$stack');
    return null;
  } finally {
    img?.dispose();
    paper?.dispose();
    unrolled?.dispose();
    paper2?.dispose();
    background?.dispose();
    flat?.dispose();
  }
}

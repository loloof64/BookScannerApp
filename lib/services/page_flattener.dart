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
  final small = await cv.resizeAsync(src, (
    _smallWidth,
    h,
  ), interpolation: cv.INTER_AREA);
  final kernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, (15, 15));
  final noText = await cv.dilateAsync(small, kernel); // dark text vanishes
  final blurred = await cv.gaussianBlurAsync(noText, (0, 0), 8);
  small.dispose();
  kernel.dispose();
  noText.dispose();
  return blurred;
}

/// Vertical displacement (px) of the text in each band, relative to the page centre.
///
/// [bands] are the ink profiles (one per vertical strip, top to bottom). Each band
/// is aligned on its neighbour, walking out from the centre, so shifts stay below
/// one line pitch and can't lock on the wrong line. Positive = content sits lower.
/// ponytail: one shift per strip (no vertical scaling), needs text lines in the strips.
List<double> verticalShifts(List<List<double>> bands, int maxStep) {
  final nb = bands.length;
  final h = bands.first.length;
  final prof = [
    for (final b in bands)
      () {
        final mean = b.reduce((a, c) => a + c) / h;
        return [for (final v in b) v - mean];
      }(),
  ];
  final energy = [
    for (final b in prof) math.sqrt(b.fold(0.0, (a, v) => a + v * v)),
  ];
  final median = ([...energy]..sort())[nb ~/ 2];

  double step(int prev, int cur) {
    // too little ink to trust (blank strip / margin / no text at all)
    final floor = math.max(0.3 * median, 2.0 * math.sqrt(h));
    if (energy[cur] < floor || energy[prev] < floor) return 0;
    final scores = [
      for (var s = -maxStep; s <= maxStep; s++)
        () {
          var score = 0.0;
          for (var y = math.max(0, -s); y < math.min(h, h - s); y++) {
            score += prof[prev][y] * prof[cur][y + s];
          }
          return score;
        }(),
    ];
    var k = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[k]) k = i;
    }
    // parabolic refinement: sub-pixel steps, otherwise rounding accumulates
    var frac = 0.0;
    if (k > 0 && k < scores.length - 1) {
      final d = scores[k - 1] - 2 * scores[k] + scores[k + 1];
      if (d < 0) frac = 0.5 * (scores[k - 1] - scores[k + 1]) / d;
    }
    return k - maxStep + frac;
  }

  final c = nb ~/ 2;
  final dy = List<double>.filled(nb, 0);
  for (var b = c + 1; b < nb; b++) {
    dy[b] = dy[b - 1] + step(b - 1, b);
  }
  for (var b = c - 1; b >= 0; b--) {
    dy[b] = dy[b + 1] + step(b + 1, b);
  }
  // light smoothing, ends kept raw (a 3-tap average would shrink them)
  return [
    for (var i = 0; i < nb; i++)
      if (i == 0 || i == nb - 1)
        dy[i]
      else
        () {
          var sum = 0.0, cnt = 0;
          for (var j = math.max(0, i - 1); j <= math.min(nb - 1, i + 1); j++) {
            sum += dy[j];
            cnt++;
          }
          return sum / cnt;
        }(),
  ];
}

/// Linear interpolation of per-band values to one value per output column.
List<double> _spreadBands(List<double> v, int width) {
  final n = v.length;
  return List<double>.generate(width, (x) {
    final t = ((x + 0.5) * n / width - 0.5).clamp(0, n - 1).toDouble();
    final i = t.floor(), j = math.min(i + 1, n - 1);
    return v[i] + (v[j] - v[i]) * (t - i);
  });
}

/// One remap: output (x, y) samples source (cols[x], y + dy[x]).
Future<cv.Mat> _remapColumns(
  cv.Mat src,
  List<double> cols,
  List<double> dy,
) async {
  final w = cols.length;
  final mapX = cv.Mat.fromList(1, w, cv.MatType.CV_32FC1, cols);
  final mapXFull = await cv.repeatAsync(mapX, src.rows, 1);
  final mapDy = cv.Mat.fromList(1, w, cv.MatType.CV_32FC1, dy);
  final mapDyFull = await cv.repeatAsync(mapDy, src.rows, 1);
  final mapY = cv.Mat.fromList(
    src.rows,
    1,
    cv.MatType.CV_32FC1,
    List<double>.generate(src.rows, (y) => y.toDouble()),
  );
  final mapYBase = await cv.repeatAsync(mapY, 1, w);
  final mapYFull = await cv.addAsync(mapYBase, mapDyFull);
  final out = await cv.remapAsync(
    src,
    mapXFull,
    mapYFull,
    cv.INTER_LANCZOS4, // stretching blurs, keep it as sharp as possible
    borderMode: cv.BORDER_REPLICATE,
  );
  for (final m in [
    mapX,
    mapXFull,
    mapDy,
    mapDyFull,
    mapY,
    mapYBase,
    mapYFull,
  ]) {
    m.dispose();
  }
  return out;
}

/// Estimates vertical text displacement per output column, in [src] pixels.
Future<List<double>> _estimateDy(
  cv.Mat src,
  List<double> weights,
  int outWidth,
) async {
  const analysisWidth = 900;
  final small = await cv.resizeAsync(src, (
    analysisWidth,
    math.max(1, src.rows * analysisWidth ~/ src.cols),
  ), interpolation: cv.INTER_AREA);
  final smallOutW = unrolledWidth(weights, analysisWidth);
  final zero = List<double>.filled(smallOutW, 0);
  final unrolledSmall = await _remapColumns(
    small,
    unrollColumns(weights, analysisWidth, smallOutW),
    zero,
  );

  // ink = how much darker than the paper (text only)
  final gray = await cv.cvtColorAsync(unrolledSmall, cv.COLOR_BGR2GRAY);
  final paperSmall = await _paperSmall(unrolledSmall);
  final paperGray = await cv.cvtColorAsync(paperSmall, cv.COLOR_BGR2GRAY);
  final paper = await cv.resizeAsync(paperGray, (gray.cols, gray.rows));
  final ratio = await cv.divideAsync(gray, paper, scale: 255);
  final ink = await cv.bitwiseNOTAsync(ratio);

  final nb = math.max(3, math.min(40, ink.cols ~/ 15));
  final bandsMat = await cv.resizeAsync(ink, (
    nb,
    ink.rows,
  ), interpolation: cv.INTER_AREA);
  final d = bandsMat.data;
  final h = ink.rows;
  final bands = [
    for (var b = 0; b < nb; b++)
      [for (var y = 0; y < h; y++) d[y * nb + b].toDouble()],
  ];
  final dySmall = verticalShifts(bands, math.max(2, h ~/ 100));

  for (final m in [
    small,
    unrolledSmall,
    gray,
    paperSmall,
    paperGray,
    paper,
    ratio,
    ink,
    bandsMat,
  ]) {
    m.dispose();
  }
  final scale = src.rows / h;
  return [for (final v in _spreadBands(dySmall, outWidth)) v * scale];
}

/// Unrolls gutter curvature (both axes), flattens the lighting, saves `<name>_flat.jpg`.
Future<String?> flattenPage(
  String imagePath, {
  bool straightenLines = true,
  bool sharpen = true,
}) async {
  cv.Mat? img;
  cv.Mat? paper;
  cv.Mat? unrolled;
  cv.Mat? paper2;
  cv.Mat? background;
  cv.Mat? flat;

  try {
    img = await cv.imreadAsync(imagePath);
    if (img.isEmpty) return null;

    // 1. Horizontal stretch driven by the paper brightness profile
    paper = await _paperSmall(img);
    final gray = await cv.cvtColorAsync(paper, cv.COLOR_BGR2GRAY);
    final row = await cv.resizeAsync(gray, (
      _smallWidth,
      1,
    ), interpolation: cv.INTER_AREA);
    final profile = row.data.map((v) => v.toDouble()).toList();
    gray.dispose();
    row.dispose();

    final weights = stretchWeights(profile);
    final outWidth = unrolledWidth(weights, img.cols);
    final cols = unrollColumns(weights, img.cols, outWidth);

    // 2. Vertical shift per column so curved text lines become straight,
    //    then a single remap for both axes (each resample costs sharpness)
    final dy = straightenLines
        ? await _estimateDy(img, weights, outWidth)
        : List<double>.filled(outWidth, 0);
    unrolled = await _remapColumns(img, cols, dy);
    debugPrint(
      'flattenPage: ${img.cols}px -> ${outWidth}px, '
      'dy ${dy.reduce(math.min).toStringAsFixed(1)}..${dy.reduce(math.max).toStringAsFixed(1)}px',
    );

    // 3. Lighting: divide by the text-free paper estimate
    paper2 = await _paperSmall(unrolled);
    background = await cv.resizeAsync(paper2, (unrolled.cols, unrolled.rows));
    final divided = await cv.divideAsync(unrolled, background, scale: 255);

    // 4. Unsharp mask to win back the sharpness lost to resampling
    final soft = await cv.gaussianBlurAsync(divided, (0, 0), 1.5);
    flat = sharpen
        ? await cv.addWeightedAsync(divided, 2.3, soft, -1.3, 0)
        : divided.clone();
    divided.dispose();
    soft.dispose();

    final outputPath = p.join(
      p.dirname(imagePath),
      '${p.basenameWithoutExtension(imagePath)}_flat_${straightenLines ? 'l' : ''}${sharpen ? 's' : ''}.jpg',
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

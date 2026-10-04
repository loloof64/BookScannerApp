// Benchmark: 400 synthetic 3000x4000 photos -> compress -> PDF. Run:
//   flutter test test/pdf_export_bench_test.dart
// Logic mirrors _compressPage in read_book_content_screen.dart.
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('400 pages export', () async {
    const n = 400;
    final dir = Directory.systemTemp.createTempSync('bench');
    final paths = <String>[];
    for (var i = 0; i < n; i++) {
      final m = cv.Mat.zeros(4000, 3000, cv.MatType.CV_8UC3);
      cv.randu(m, cv.Scalar(0, 0, 0, 0), cv.Scalar(255, 255, 255, 0));
      final blur = cv.gaussianBlur(m, (31, 31), 0); // photo-ish size/entropy
      final path = '${dir.path}/p$i.jpg';
      cv.imwrite(path, blur);
      m.dispose();
      blur.dispose();
      paths.add(path);
    }
    final srcMb = paths.fold<int>(0, (a, p) => a + File(p).lengthSync()) / 1e6;
    debugPrint(
      'source: ${srcMb.toStringAsFixed(0)} MB, rss ${ProcessInfo.currentRss ~/ 1e6} MB',
    );

    final sw = Stopwatch()..start();
    final doc = pw.Document();
    var peak = 0;
    for (final path in paths) {
      final img = await cv.imreadAsync(path);
      final scale = 1800 / (img.width > img.height ? img.width : img.height);
      final small = await cv.resizeAsync(img, (
        (img.width * scale).round(),
        (img.height * scale).round(),
      ), interpolation: cv.INTER_AREA);
      final (_, bytes) = await cv.imencodeAsync(
        '.jpg',
        small,
        params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 70]),
      );
      doc.addPage(pw.Page(
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
              child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain))));
      small.dispose();
      img.dispose();
      if (ProcessInfo.currentRss > peak) peak = ProcessInfo.currentRss;
    }
    debugPrint(
      'compressed in ${sw.elapsed.inSeconds}s, rss peak ${peak ~/ 1e6} MB',
    );
    final pdf = await doc.save();
    debugPrint(
      'save done ${sw.elapsed.inSeconds}s, pdf ${pdf.length ~/ 1e6} MB, '
      'max rss ${ProcessInfo.maxRss ~/ 1e6} MB',
    );
    dir.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 20)));
}

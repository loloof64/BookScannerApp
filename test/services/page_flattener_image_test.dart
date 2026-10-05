import 'dart:io';

import 'package:book_scanner_app/services/page_flattener.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void main() {
  test('flattenPage widens a page with a dark gutter and writes a jpg', () async {
    final dir = Directory.systemTemp.createTempSync('flat');
    // white page, right 20% shaded to ~70%
    final m = cv.Mat.zeros(600, 800, cv.MatType.CV_8UC3);
    for (var x = 0; x < 800; x++) {
      final v = x < 640 ? 230.0 : 230.0 - (x - 640) * 0.5;
      cv.line(m, cv.Point(x, 0), cv.Point(x, 599), cv.Scalar(v, v, v, 0));
    }
    final path = '${dir.path}/page.jpg';
    cv.imwrite(path, m);

    final out = await flattenPage(path);
    expect(out, isNotNull);
    final r = cv.imread(out!);
    expect(r.cols, greaterThan(800));
    expect(r.rows, 600);
    // lighting flattened: right edge about as bright as the left
    final left = r.at<cv.Vec3b>(300, 50).val1;
    final right = r.at<cv.Vec3b>(300, r.cols - 20).val1;
    expect((left - right).abs(), lessThan(25));
  });
}

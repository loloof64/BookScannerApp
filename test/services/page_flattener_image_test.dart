import 'dart:io';

import 'package:book_scanner_app/services/page_flattener.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void main() {
  test(
    'flattenPage widens a page with a dark gutter and writes a jpg',
    () async {
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
    },
  );

  test('flattenPage straightens text lines that sag near the fold', () async {
    final dir = Directory.systemTemp.createTempSync('flat');
    final m = cv.Mat.zeros(600, 800, cv.MatType.CV_8UC3);
    cv.rectangle(
      m,
      cv.Rect(0, 0, 800, 600),
      cv.Scalar(235, 235, 235, 0),
      thickness: -1,
    );
    // text lines every 40px, sagging up to 30px right of x=600
    for (var x = 0; x < 800; x++) {
      final sag = x < 600 ? 0 : ((x - 600) * 0.15).round();
      for (var line = 0; line < 13; line++) {
        final y = 40 + line * 40 + sag;
        cv.line(
          m,
          cv.Point(x, y),
          cv.Point(x, y + 8),
          cv.Scalar(30, 30, 30, 0),
        );
      }
    }
    final path = '${dir.path}/page.jpg';
    cv.imwrite(path, m);

    final r = cv.imread((await flattenPage(path))!);
    int firstDark(int x) {
      for (var y = 100; y < 500; y++) {
        if (r.at<cv.Vec3b>(y, x).val1 < 120) return y;
      }
      return -1;
    }

    // a line near the fold lines up with the same line at the page centre (mod pitch)
    final centre = firstDark(300);
    final fold = firstDark(r.cols - 15);
    expect(
      ((fold - centre) % 40 + 40) % 40 < 4 || ((fold - centre) % 40) > 36,
      isTrue,
      reason: 'centre=$centre fold=$fold',
    );
  });

  test('flattenPage corrects the horn effect (top up, bottom down)', () async {
    final dir = Directory.systemTemp.createTempSync('flat');
    final m = cv.Mat.zeros(600, 800, cv.MatType.CV_8UC3);
    cv.rectangle(
      m,
      cv.Rect(0, 0, 800, 600),
      cv.Scalar(235, 235, 235, 0),
      thickness: -1,
    );
    // lines every 40px; right of x=600 they fan out: up to -20px on top, +20px at bottom
    for (var x = 0; x < 800; x++) {
      final k = x < 600 ? 0.0 : (x - 600) / 200;
      for (var line = 0; line < 13; line++) {
        final y0 = 40 + line * 40;
        final y = y0 + (k * 20 * (y0 - 300) / 260).round();
        cv.line(
          m,
          cv.Point(x, y),
          cv.Point(x, y + 8),
          cv.Scalar(30, 30, 30, 0),
        );
      }
    }
    final path = '${dir.path}/page.jpg';
    cv.imwrite(path, m);

    final r = cv.imread((await flattenPage(path))!);
    int firstDark(int x) {
      for (var y = 0; y < r.rows; y++) {
        if (r.at<cv.Vec3b>(y, x).val1 < 120) return y;
      }
      return -1;
    }

    int lastDark(int x) {
      for (var y = r.rows - 1; y >= 0; y--) {
        if (r.at<cv.Vec3b>(y, x).val1 < 120) return y;
      }
      return -1;
    }

    // uncorrected, the top line is 20px higher and the bottom line 20px lower at the fold
    expect((firstDark(r.cols - 15) - firstDark(300)).abs(), lessThan(8));
    expect((lastDark(r.cols - 15) - lastDark(300)).abs(), lessThan(8));
  });

  test('flattenPage corrects a bow near the fold (middle lines pushed down)', () async {
    final dir = Directory.systemTemp.createTempSync('flat');
    final m = cv.Mat.zeros(600, 800, cv.MatType.CV_8UC3);
    cv.rectangle(
      m,
      cv.Rect(0, 0, 800, 600),
      cv.Scalar(235, 235, 235, 0),
      thickness: -1,
    );
    // right of x=600 the middle lines sag up to 20px, top/bottom lines stay put
    for (var x = 0; x < 800; x++) {
      final k = x < 600 ? 0.0 : (x - 600) / 200;
      for (var line = 0; line < 13; line++) {
        final y0 = 40 + line * 40;
        final u = (y0 - 300) / 260;
        final y = y0 + (k * 20 * (1 - u * u)).round();
        cv.line(
          m,
          cv.Point(x, y),
          cv.Point(x, y + 8),
          cv.Scalar(30, 30, 30, 0),
        );
      }
    }
    final path = '${dir.path}/page.jpg';
    cv.imwrite(path, m);

    final r = cv.imread((await flattenPage(path))!);
    // first dark row at or below y=270 (the centre line sits at 280..288 in the source)
    int midLine(int x) {
      for (var y = 255; y < r.rows; y++) {
        if (r.at<cv.Vec3b>(y, x).val1 < 120) return y;
      }
      return -1;
    }

    expect((midLine(r.cols - 15) - midLine(300)).abs(), lessThan(8));
  });
}

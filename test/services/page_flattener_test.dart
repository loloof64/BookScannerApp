import 'package:book_scanner_app/services/page_flattener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flat page is untouched', () {
    final w = stretchWeights(List.filled(100, 200.0));
    expect(unrolledWidth(w, 1000), 1000);
    final c = unrollColumns(w, 1000, 1000);
    expect(c[0], closeTo(0.5, 1));
    expect(c[500], closeTo(500, 1));
  });

  test('dark gutter side gets stretched, monotone mapping', () {
    // right 20% fades to 70% brightness
    final profile = [
      for (var i = 0; i < 100; i++) i < 80 ? 200.0 : 200.0 - (i - 80) * 3.5,
    ];
    final w = stretchWeights(profile);
    final out = unrolledWidth(w, 1000);
    expect(out, greaterThan(1000));
    final c = unrollColumns(w, 1000, out);
    for (var j = 1; j < c.length; j++) {
      expect(c[j], greaterThanOrEqualTo(c[j - 1]));
    }
    // left part not stretched: output x ~ source x
    expect(c[300], closeTo(300, 15));
    // gutter part: output advances faster than source
    expect(c.last - c[out - 100], lessThan(100));
  });

  test('verticalShifts recovers a progressive downward bend', () {
    const h = 300;
    List<double> lines(int shift) => [
      for (var y = 0; y < h; y++)
        ((y - shift) % 30 < 8) ? 255.0 : 0.0, // text lines every 30px
    ];
    // 11 bands, content sags 1px more per band right of centre (band 5)
    final bands = [
      for (var b = 0; b < 11; b++) lines(b <= 5 ? 0 : (b - 5) * 2),
    ];
    final dy = verticalShifts(bands, 5);
    expect(dy[5], closeTo(0, 1));
    expect(dy[10], closeTo(10, 1));
    expect(dy[0], closeTo(0, 1));
  });
}

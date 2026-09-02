import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/widgets/fluid_gauge.dart';

void main() {
  test('gaugeColor thresholds', () {
    expect(gaugeColor(649, 1000), Colors.green);
    expect(gaugeColor(800, 1000), Colors.amber);
    expect(gaugeColor(1001, 1000), Colors.red);
  });
}

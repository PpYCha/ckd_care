import 'package:flutter_test/flutter_test.dart';
import 'package:ckd_care/theme/app_theme.dart';

void main() {
  test('fluidStatus color thresholds', () {
    // ratio = intake / limit: under 0.8 -> water, 0.8..1.0 -> warn, over -> over.
    expect(AppColors.fluidStatus(649 / 1000), AppColors.water);
    expect(AppColors.fluidStatus(800 / 1000), AppColors.warn);
    expect(AppColors.fluidStatus(1001 / 1000), AppColors.over);
  });
}

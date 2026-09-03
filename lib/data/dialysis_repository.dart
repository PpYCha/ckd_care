import 'dart:convert';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:ckd_care/models/dialysis_center.dart';

/// Loads the bundled accredited-dialysis-center list (read-only reference data)
/// and answers region/province/list queries from an in-memory cache.
class DialysisRepository {
  static const _assetPath = 'assets/data/dialysis_centers.json';

  // Fixed display order for the region dropdown (geographic, north to south).
  static const _regionOrder = [
    'CORDILLERA ADMINISTRATIVE REGION',
    'REGION I', 'REGION II', 'REGION III',
    'NATIONAL CAPITAL REGION & RIZAL',
    'REGION IV-A', 'REGION IV-B', 'REGION V',
    'REGION VI', 'REGION VII', 'REGION VIII',
    'REGION IX', 'REGION X', 'REGION XI', 'REGION XII',
    'CARAGA REGION', 'BANGSAMORO AUTONOMOUS REGION (BARMM)',
  ];

  List<DialysisCenter> _all = const [];
  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load({AssetBundle? bundle}) async {
    if (_loaded) return;
    final raw = await (bundle ?? rootBundle).loadString(_assetPath);
    final list = (json.decode(raw) as List)
        .map((e) => DialysisCenter.fromJson(e as Map<String, dynamic>))
        .toList();
    _all = list;
    _loaded = true;
  }

  List<String> get regions {
    final present = _all.map((c) => c.region).toSet();
    return _regionOrder.where(present.contains).toList();
  }

  List<String> provincesIn(String region) {
    final set = _all
        .where((c) => c.region == region)
        .map((c) => c.province)
        .toSet()
        .toList()
      ..sort();
    return set;
  }

  List<DialysisCenter> centersIn(String region, String province) {
    final list = _all
        .where((c) => c.region == region && c.province == province)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}

class DialysisCenter {
  const DialysisCenter({
    required this.num,
    required this.region,
    required this.province,
    required this.name,
    required this.tels,
    required this.emails,
    required this.street,
    required this.municipality,
    required this.expiry,
    required this.sec,
  });

  final int num;
  final String region;
  final String province;
  final String name;
  final List<String> tels;
  final List<String> emails;
  final String street;
  final String municipality;
  final List<String> expiry;
  final String sec;

  static List<String> _strList(Object? v) =>
      v == null ? const [] : (v as List).map((e) => e.toString()).toList();

  factory DialysisCenter.fromJson(Map<String, dynamic> j) => DialysisCenter(
        num: j['num'] as int,
        region: j['region'] as String,
        province: j['province'] as String,
        name: j['name'] as String,
        tels: _strList(j['tels']),
        emails: _strList(j['emails']),
        street: (j['street'] ?? '') as String,
        municipality: (j['municipality'] ?? '') as String,
        expiry: _strList(j['expiry']),
        sec: (j['sec'] ?? '') as String,
      );

  String get address =>
      [street, municipality].where((s) => s.trim().isNotEmpty).join(', ');
}

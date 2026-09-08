enum FluidType { intake, output }

class FluidEntry {
  const FluidEntry({
    this.id,
    required this.uuid,
    required this.type,
    required this.amountMl,
    required this.loggedAt,
    required this.day,
    this.note,
    required this.updatedAt,
    this.deleted = false,
  });

  final int? id;
  final String uuid;
  final FluidType type;
  final int amountMl;
  final DateTime loggedAt;
  final String day;
  final String? note;
  final DateTime updatedAt;
  final bool deleted;

  static String dayOf(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  factory FluidEntry.fromMap(Map<String, Object?> m) => FluidEntry(
        id: m['id'] as int?,
        uuid: m['uuid'] as String,
        type: FluidType.values.byName(m['type'] as String),
        amountMl: m['amount_ml'] as int,
        loggedAt: DateTime.parse(m['logged_at'] as String),
        day: m['day'] as String,
        note: m['note'] as String?,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        deleted: (m['deleted'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'type': type.name,
        'amount_ml': amountMl,
        'logged_at': loggedAt.toIso8601String(),
        'day': day,
        'note': note,
        'updated_at': updatedAt.toIso8601String(),
        'deleted': deleted ? 1 : 0,
      };
}

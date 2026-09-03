class Medicine {
  const Medicine({
    this.id,
    required this.uuid,
    required this.name,
    this.dosage,
    this.active = true,
    required this.stockQty,
    this.endDate,
    this.consumeUntilEmpty = false,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final int? id;
  final String uuid;
  final String name;
  final String? dosage;
  final bool active;
  final int stockQty;
  final DateTime? endDate;

  /// true = a finite course taken until stock runs out; false = indefinite
  /// maintenance med. Purely classification — the dashboard already hides any
  /// medicine at 0 stock.
  final bool consumeUntilEmpty;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  /// 'YYYY-MM-DD' for storage/comparison.
  static String fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  factory Medicine.fromMap(Map<String, Object?> m) => Medicine(
        id: m['id'] as int?,
        uuid: m['uuid'] as String,
        name: m['name'] as String,
        dosage: m['dosage'] as String?,
        active: (m['active'] as int) == 1,
        stockQty: m['stock_qty'] as int,
        endDate: m['end_date'] == null
            ? null
            : DateTime.parse(m['end_date'] as String),
        consumeUntilEmpty: (m['consume_until_empty'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        deleted: (m['deleted'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'name': name,
        'dosage': dosage,
        'active': active ? 1 : 0,
        'stock_qty': stockQty,
        'end_date': endDate == null ? null : fmtDate(endDate!),
        'consume_until_empty': consumeUntilEmpty ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted': deleted ? 1 : 0,
      };
}

class MedicineTime {
  const MedicineTime({
    this.id,
    required this.uuid,
    this.medicineId,
    required this.medicineUuid,
    required this.timeOfDay,
    required this.updatedAt,
    this.deleted = false,
  });

  final int? id;
  final String uuid;
  final int? medicineId;
  final String medicineUuid;
  final String timeOfDay; // 'HH:mm'
  final DateTime updatedAt;
  final bool deleted;

  factory MedicineTime.fromMap(Map<String, Object?> m) => MedicineTime(
        id: m['id'] as int?,
        uuid: m['uuid'] as String,
        medicineId: m['medicine_id'] as int?,
        medicineUuid: m['medicine_uuid'] as String,
        timeOfDay: m['time_of_day'] as String,
        updatedAt: DateTime.parse(m['updated_at'] as String),
        deleted: (m['deleted'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        if (medicineId != null) 'medicine_id': medicineId,
        'medicine_uuid': medicineUuid,
        'time_of_day': timeOfDay,
        'updated_at': updatedAt.toIso8601String(),
        'deleted': deleted ? 1 : 0,
      };
}

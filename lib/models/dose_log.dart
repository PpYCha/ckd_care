enum DoseStatus { taken, skipped }

class DoseLog {
  const DoseLog({
    this.id,
    required this.uuid,
    required this.medicineId,
    required this.scheduledTime,
    required this.status,
    required this.actedAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final int? id;
  final String uuid;
  final int medicineId;
  final DateTime scheduledTime;
  final DoseStatus status;
  final DateTime actedAt;
  final DateTime updatedAt;
  final bool deleted;

  factory DoseLog.fromMap(Map<String, Object?> m) => DoseLog(
        id: m['id'] as int?,
        uuid: m['uuid'] as String,
        medicineId: m['medicine_id'] as int,
        scheduledTime: DateTime.parse(m['scheduled_time'] as String),
        status: DoseStatus.values.byName(m['status'] as String),
        actedAt: DateTime.parse(m['acted_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        deleted: (m['deleted'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'medicine_id': medicineId,
        'scheduled_time': scheduledTime.toIso8601String(),
        'status': status.name,
        'acted_at': actedAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'deleted': deleted ? 1 : 0,
      };
}

import 'package:flutter/foundation.dart';

@immutable
class DialysisSessionLog {
  const DialysisSessionLog({
    this.id,
    required this.sessionKey,
    required this.sessionStart,
    this.preWeightKg,
    this.postWeightKg,
    required this.updatedAt,
  });

  final int? id;
  final String sessionKey;
  final DateTime sessionStart;
  final double? preWeightKg;
  final double? postWeightKg;
  final DateTime updatedAt;

  bool get hasWeights => preWeightKg != null || postWeightKg != null;

  double? get removedWeightKg {
    final pre = preWeightKg;
    final post = postWeightKg;
    if (pre == null || post == null || post > pre) return null;
    return pre - post;
  }

  DialysisSessionLog copyWith({
    int? id,
    String? sessionKey,
    DateTime? sessionStart,
    Object? preWeightKg = _sentinel,
    Object? postWeightKg = _sentinel,
    DateTime? updatedAt,
  }) => DialysisSessionLog(
    id: id ?? this.id,
    sessionKey: sessionKey ?? this.sessionKey,
    sessionStart: sessionStart ?? this.sessionStart,
    preWeightKg: preWeightKg == _sentinel
        ? this.preWeightKg
        : preWeightKg as double?,
    postWeightKg: postWeightKg == _sentinel
        ? this.postWeightKg
        : postWeightKg as double?,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory DialysisSessionLog.empty(DateTime sessionStart) {
    final start = normalizedSessionStart(sessionStart);
    return DialysisSessionLog(
      sessionKey: sessionKeyFor(start),
      sessionStart: start,
      updatedAt: DateTime.now(),
    );
  }

  factory DialysisSessionLog.fromMap(Map<String, Object?> m) =>
      DialysisSessionLog(
        id: m['id'] as int?,
        sessionKey: m['session_key'] as String,
        sessionStart: DateTime.parse(m['session_start'] as String),
        preWeightKg: (m['pre_weight_kg'] as num?)?.toDouble(),
        postWeightKg: (m['post_weight_kg'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'session_key': sessionKey,
    'session_start': sessionStart.toIso8601String(),
    'pre_weight_kg': preWeightKg,
    'post_weight_kg': postWeightKg,
    'updated_at': updatedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is DialysisSessionLog &&
      other.id == id &&
      other.sessionKey == sessionKey &&
      other.sessionStart == sessionStart &&
      other.preWeightKg == preWeightKg &&
      other.postWeightKg == postWeightKg &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    sessionKey,
    sessionStart,
    preWeightKg,
    postWeightKg,
    updatedAt,
  );
}

const Object _sentinel = Object();

DateTime normalizedSessionStart(DateTime start) =>
    DateTime(start.year, start.month, start.day, start.hour, start.minute);

String sessionKeyFor(DateTime start) =>
    normalizedSessionStart(start).toIso8601String();

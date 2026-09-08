import 'package:flutter/foundation.dart';
import 'package:ckd_care/models/dialysis_session_log.dart';
import 'package:ckd_care/repositories/dialysis_session_log_repository.dart';

class DialysisSessionLogProvider extends ChangeNotifier {
  DialysisSessionLogProvider(this._repo);
  final DialysisSessionLogRepository _repo;

  Map<String, DialysisSessionLog> logsBySessionKey = const {};

  Future<void> loadForSessions(Iterable<DateTime> sessionStarts) async {
    logsBySessionKey = await _repo.logsForSessions(sessionStarts);
    notifyListeners();
  }

  DialysisSessionLog? logFor(DateTime sessionStart) =>
      logsBySessionKey[sessionKeyFor(sessionStart)];

  Future<void> saveWeights({
    required DateTime sessionStart,
    Object? preWeightKg = kDialysisWeightUnchanged,
    Object? postWeightKg = kDialysisWeightUnchanged,
  }) async {
    await _repo.saveWeights(
      sessionStart: sessionStart,
      preWeightKg: preWeightKg,
      postWeightKg: postWeightKg,
    );
    await loadForSessions([
      ...logsBySessionKey.values.map((log) => log.sessionStart),
      sessionStart,
    ]);
  }
}

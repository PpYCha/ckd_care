import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Client-generated v4 UUID — the sync-stable identity for every data row.
String newUuid() => _uuid.v4();

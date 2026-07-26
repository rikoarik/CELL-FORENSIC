import 'dart:convert';

/// Deterministic UUID (v5-style) from a stable name — valid for Postgres uuid
/// columns without adding a package dependency.
String stableEntityUuid(String name) {
  final data = utf8.encode('cell-forensic:$name');
  final bytes = List<int>.filled(16, 0);
  for (var i = 0; i < data.length; i++) {
    final b = data[i];
    bytes[i % 16] ^= b;
    bytes[(i + 7) % 16] = (bytes[(i + 7) % 16] + b * 31) & 0xff;
    bytes[(i + 13) % 16] = (bytes[(i + 13) % 16] + (b << 1)) & 0xff;
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x50; // version 5
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122
  String hex(int start, int end) {
    final buffer = StringBuffer();
    for (var i = start; i < end; i++) {
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

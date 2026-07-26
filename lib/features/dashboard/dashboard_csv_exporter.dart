import 'package:cell_forensic/features/dashboard/dashboard_models.dart';

/// Builds RFC-style CSV for teacher export (E6-04 / FR-106).
abstract final class DashboardCsvExporter {
  static const List<String> headers = [
    'kode_sesi',
    'judul_sesi',
    'nama_kelompok',
    'anggota',
    'kode_pos',
    'kode_soal',
    'tipe_soal',
    'jawaban',
    'skor_otomatis',
    'skor_guru',
    'skor_akhir',
    'butuh_review',
    'umpan_balik',
  ];

  static String build(List<DashboardExportRow> rows) {
    // UTF-8 BOM so Excel on Windows opens Indonesian text correctly.
    final buffer = StringBuffer('\uFEFF')
      ..writeln(headers.map(escape).join(','));
    for (final row in rows) {
      buffer.writeln(
        [
          row.sessionJoinCode,
          row.sessionTitle,
          row.groupName,
          row.memberNames,
          row.stationCode,
          row.questionCode,
          row.questionType,
          row.answerText,
          _num(row.autoScore),
          _num(row.teacherScore),
          _num(row.finalScore),
          row.requiresReview ? 'ya' : 'tidak',
          row.feedback,
        ].map(escape).join(','),
      );
    }
    return buffer.toString();
  }

  static String escape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _num(num? value) => value?.toString() ?? '';
}

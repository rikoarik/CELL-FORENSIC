import 'package:cell_forensic/features/dashboard/dashboard_csv_exporter.dart';
import 'package:cell_forensic/features/dashboard/dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV mengekspor header dan baris skor/jawaban', () {
    final csv = DashboardCsvExporter.build([
      const DashboardExportRow(
        sessionJoinCode: 'CELL01',
        sessionTitle: 'Praktikum Demo',
        groupName: 'Kelompok Mawar',
        memberNames: 'Ani; Budi',
        questionCode: 'POS1-Q1',
        questionType: 'objective',
        stationCode: 'POS-1',
        answerText: 'Sampel A',
        autoScore: 10,
        teacherScore: null,
        finalScore: 10,
        requiresReview: false,
        feedback: '',
      ),
      const DashboardExportRow(
        sessionJoinCode: 'CELL01',
        sessionTitle: 'Praktikum Demo',
        groupName: 'Kelompok Mawar',
        memberNames: 'Ani; Budi',
        questionCode: 'POS1-Q2',
        questionType: 'essay',
        stationCode: 'POS-1',
        answerText: 'Melindungi sel, ya',
        autoScore: 0,
        teacherScore: 4,
        finalScore: 4,
        requiresReview: false,
        feedback: 'Cukup, tambah bukti',
      ),
    ]);

    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv, contains('kode_sesi,judul_sesi,nama_kelompok'));
    expect(csv, contains('CELL01'));
    expect(csv, contains('Kelompok Mawar'));
    expect(csv, contains('POS1-Q1'));
    expect(csv, contains('Sampel A'));
    expect(csv, contains('tidak'));
    expect(csv, contains('Cukup, tambah bukti'));
  });

  test('escape CSV mengutip koma dan tanda kutip', () {
    expect(DashboardCsvExporter.escape('a,b'), '"a,b"');
    expect(DashboardCsvExporter.escape('katakan "halo"'), '"katakan ""halo"""');
  });
}

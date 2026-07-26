import 'package:cell_forensic/domain/intent_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final matcher = IntentMatcher([
    IntentRule(
      code: 'inspect_sample_a_organel',
      keywords: {'sampel a', 'organel'},
      response: 'Kloroplas dan vakuola merupakan organel pada sel tumbuhan.',
      sequenceCode: 'SEQ-MISI-1',
    ),
    IntentRule(
      code: 'request_hint',
      keywords: {'petunjuk'},
      response: 'Coba tanyakan organel pada Sampel A.',
    ),
  ]);

  test('menormalisasi huruf kecil dan spasi sebelum mencocokkan intent', () {
    final result = matcher.match('  LIHAT ORGANEL PADA SAMPEL A  ');

    expect(result.intentCode, 'inspect_sample_a_organel');
    expect(result.sequenceCode, 'SEQ-MISI-1');
  });

  test('mengembalikan unknown saat pertanyaan tidak dikenali', () {
    final result = matcher.match('apa warna langit?');

    expect(result.intentCode, IntentMatcher.unknownIntent);
    expect(result.response, IntentMatcher.unknownResponse);
    expect(result.sequenceCode, isNull);
  });

  test(
    'mengembalikan unknown saat pertanyaan cocok ke lebih dari satu intent',
    () {
      final result = matcher.match('petunjuk organel sampel a');

      expect(result.intentCode, IntentMatcher.unknownIntent);
      // Ambiguous rules → unknown text, but PDF keywords still map to Misi 1 AR.
      expect(result.missionNumber, 1);
      expect(result.sequenceCode, 'SEQ-MISI-1');
    },
  );

  test('mengembalikan fakta inti hanya dari respons aturan tervalidasi', () {
    final result = matcher.match('organel sampel a');

    expect(
      result.response,
      'Kloroplas dan vakuola merupakan organel pada sel tumbuhan.',
    );
  });

  test('menolak label provisional Organel X/Y tanpa mengarang biologi', () {
    final result = matcher.match('apa fungsi organel x pada sampel a?');

    expect(result.intentCode, IntentMatcher.provisionalIntent);
    expect(result.response, IntentMatcher.provisionalResponse);
  });

  test('menolak pertanyaan membran bernomor provisional', () {
    final result = matcher.match('jelaskan membran 1');

    expect(result.intentCode, IntentMatcher.provisionalIntent);
  });

  test('menandai off-topic terkontrol', () {
    final result = matcher.match('berapa suhu ruangan hari ini');

    expect(result.intentCode, IntentMatcher.offTopicIntent);
    expect(result.response, IntentMatcher.offTopicResponse);
  });

  group('classifyMission (pemetaan intent → misi dari PDF)', () {
    test('Misi 1: Sampel A + rusak/organel', () {
      expect(
        IntentMatcher.classifyMission(
          'AI, tolong periksa organel apa saja yang rusak di Sampel A?',
        ),
        1,
      );
      expect(
        IntentMatcher.classifyMission('kloroplas dan vakuola sampel a'),
        1,
      );
      // PDF keyword pair without requiring exact IntentRule keyword AND-set.
      expect(IntentMatcher.classifyMission('sampel a rusak'), 1);
    });

    test('Misi 2: Sampel B + bocor/cairan/membran', () {
      expect(
        IntentMatcher.classifyMission(
          'Mengapa cairan di dalam Sampel B bisa bocor keluar?',
        ),
        2,
      );
      expect(
        IntentMatcher.classifyMission('kondisi membran pada sampel b'),
        2,
      );
      expect(IntentMatcher.classifyMission('sampel b bocor'), 2);
    });

    test('Misi 3: Sampel A tidak hancur / perbedaan / bentuk tetap', () {
      expect(
        IntentMatcher.classifyMission(
          'Kenapa Sampel A tidak hancur sekempes Sampel B '
          'padahal sama-sama diserang?',
        ),
        3,
      );
      expect(
        IntentMatcher.classifyMission('apa perbedaan sampel a dan sampel b'),
        3,
      );
      expect(
        IntentMatcher.classifyMission('kenapa bentuknya tetap kaku'),
        3,
      );
    });

    test('kedua sampel disebut bersama diperlakukan sebagai perbandingan', () {
      expect(
        IntentMatcher.classifyMission('bandingkan sampel a dengan sampel b'),
        3,
      );
    });

    test('pertanyaan tanpa progres misi mengembalikan null', () {
      expect(IntentMatcher.classifyMission('apa warna langit?'), isNull);
      expect(IntentMatcher.classifyMission('minta petunjuk dong'), isNull);
      expect(IntentMatcher.classifyMission('organel x pada sampel a'), isNull);
      expect(IntentMatcher.classifyMission('berapa suhu ruangan'), isNull);
      expect(IntentMatcher.classifyMission(''), isNull);
    });
  });

  test('match menyertakan missionNumber untuk pertanyaan Misi 1', () {
    final result = matcher.match('organel apa yang rusak di sampel a');

    expect(result.missionNumber, 1);
    expect(result.hasMission, isTrue);
  });

  test('missionNumber null untuk provisional dan off-topic', () {
    expect(matcher.match('apa fungsi organel x pada sampel a?').missionNumber,
        isNull);
    expect(matcher.match('berapa suhu ruangan hari ini').missionNumber, isNull);
  });

  test('IntentRule.missionNumber eksplisit mengalahkan klasifikasi kata kunci',
      () {
    final ruleMatcher = IntentMatcher(const [
      IntentRule(
        code: 'compare_outer_layers',
        keywords: {'lapisan'},
        response: 'Bandingkan lapisan terluar kedua sampel.',
        sequenceCode: 'SEQ-MISI-3',
        missionNumber: 3,
      ),
    ]);

    final result = ruleMatcher.match('amati lapisan terluar');

    expect(result.intentCode, 'compare_outer_layers');
    expect(result.missionNumber, 3);
  });

  test('klasifikasi misi tanpa rule tunggal tetap mengisi sequenceCode', () {
    // PDF M2 example: Sampel B + bocor/cairan (no curated rule keywords).
    final result = matcher.match(
      'Mengapa cairan di dalam Sampel B bisa bocor keluar?',
    );

    expect(result.missionNumber, 2);
    expect(result.sequenceCode, 'SEQ-MISI-2');
  });
}

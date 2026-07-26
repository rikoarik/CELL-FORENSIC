import 'package:cell_forensic/domain/intent_matcher.dart';
import 'package:cell_forensic/domain/sequence_engine.dart';

/// Kind of a station question, deciding how it is scored locally.
enum QuestionKind { objective, essay }

/// A single evaluation question inside a POS station.
class QuestionContent {
  const QuestionContent({
    required this.code,
    required this.text,
    required this.kind,
    required this.maxScore,
    this.correctAnswer,
    this.rubric,
  });

  final String code;
  final String text;
  final QuestionKind kind;
  final int maxScore;

  /// Expected answer for [QuestionKind.objective]; `null` for essays.
  final String? correctAnswer;

  /// Guidance for teacher review of [QuestionKind.essay] answers.
  final String? rubric;
}

/// A POS evaluation station, unlocked via [markerCode] or [pin] fallback.
class StationContent {
  const StationContent({
    required this.code,
    required this.title,
    required this.pin,
    required this.questions,
    this.markerCode,
  });

  final String code;
  final String title;
  final String pin;

  /// Physical/printed marker id for this station (FR-091). Defaults to [code].
  final String? markerCode;

  final List<QuestionContent> questions;

  /// Resolved marker identifier used by scan unlock (FR-091 / FR-092).
  String get resolvedMarkerCode => markerCode ?? code;
}

/// A guided AR/fallback mission with its logbook prompts and AR sequence.
class MissionContent {
  const MissionContent({
    required this.code,
    required this.title,
    required this.sampleRef,
    required this.orderNumber,
    required this.briefing,
    required this.logbookPrompts,
    required this.sequence,
    required this.intentRules,
  });

  final String code;
  final String title;
  final String sampleRef;
  final int orderNumber;
  final String briefing;
  final List<String> logbookPrompts;
  final SequenceConfig sequence;
  final List<IntentRule> intentRules;
}

/// A fully local, offline content version: one session plus its missions,
/// stations, and assistant intent rules. This stands in for the Supabase
/// `/content-pack` response so the student app runs end-to-end without network.
class ContentPack {
  const ContentPack({
    required this.sessionTitle,
    required this.joinCode,
    required this.stationDurationSeconds,
    required this.missions,
    required this.stations,
  });

  final String sessionTitle;
  final String joinCode;
  final int stationDurationSeconds;
  final List<MissionContent> missions;
  final List<StationContent> stations;

  /// All intent rules across missions, used to build the shared assistant.
  List<IntentRule> get allIntentRules => [
    for (final mission in missions) ...mission.intentRules,
  ];
}

/// Builds the seeded, offline-first content pack for the student MVP.
///
/// Facts here mirror the validated scenario in `docs`; provisional biology
/// (Organel X/Y, membrane numbers) is intentionally left to teacher review and
/// never asserted as fact.
ContentPack buildLocalContentPack() {
  return const ContentPack(
    sessionTitle: 'Praktikum Forensik Sel — Kelas Demo',
    joinCode: 'CELL01',
    stationDurationSeconds: 300,
    missions: [
      MissionContent(
        code: 'MISI-1',
        title: 'Misi 1 — Investigasi Internal Sampel A',
        sampleRef: 'SAMPLE_A',
        orderNumber: 1,
        briefing:
            'Fokus ke Sampel A. Amati organel di dalam sel dan catat gejala '
            'yang terlihat pada logbook.',
        logbookPrompts: [
          'Bentuk/gejala klinis yang terlihat pada Sampel A',
          'Organel yang tampak rusak',
          'Warna dan efek AR yang muncul',
          'Fungsi organel dan dampak kerusakannya',
        ],
        sequence: MissionSequences.misi1,
        intentRules: [
          // PDF Misi 1: Sampel A + rusak/organel
          IntentRule(
            code: 'inspect_sample_a_organel',
            keywords: {'sampel a'},
            anyKeywords: {
              'organel',
              'rusak',
              'kerusakan',
              'kloroplas',
              'vakuola',
              'nukleus',
              'sekarat',
            },
            response:
                'Perhatikan organel tervalidasi di Sampel A (mis. nukleus, '
                'kloroplas, vakuola). Amati warna glow dan perubahan bentuk, '
                'lalu catat pada logbook. Jangan mengarang label Organel X/Y.',
            sequenceCode: 'SEQ-MISI-1',
            missionNumber: 1,
          ),
          IntentRule(
            code: 'request_hint_m1',
            keywords: {'petunjuk', 'sampel a'},
            response:
                'Coba tanyakan organel yang rusak pada Sampel A, misalnya '
                '"organel apa yang rusak di Sampel A?".',
          ),
        ],
      ),
      MissionContent(
        code: 'MISI-2',
        title: 'Misi 2 — Membran Sampel B',
        sampleRef: 'SAMPLE_B',
        orderNumber: 2,
        briefing:
            'Fokus ke Sampel B. Amati lapisan membran dan kebocoran yang '
            'terjadi, lalu lengkapi logbook Misi 2.',
        logbookPrompts: [
          'Kondisi membran Sampel B',
          'Bahan penyusun lapisan terluar',
          'Efek AR (partikel/cairan) yang muncul',
          'Dampak kerusakan membran',
        ],
        sequence: MissionSequences.misi2,
        intentRules: [
          // PDF Misi 2: Sampel B + bocor/cairan/membran
          // e.g. "Mengapa cairan di dalam Sampel B bisa bocor keluar?"
          IntentRule(
            code: 'inspect_sample_b_membrane',
            keywords: {'sampel b'},
            anyKeywords: {
              'bocor',
              'cairan',
              'membran',
              'fosfolipid',
              'bilayer',
              'permeabel',
              'hidrofobik',
            },
            response:
                'Amati lapisan membran Sampel B secara keseluruhan. Perhatikan '
                'bagian yang tampak robek dan cairan yang keluar, lalu catat '
                'pada logbook. Jangan mengarang "membran 1/2".',
            sequenceCode: 'SEQ-MISI-2',
            missionNumber: 2,
          ),
          IntentRule(
            code: 'request_hint_m2',
            keywords: {'petunjuk', 'sampel b'},
            response:
                'Coba tanyakan kebocoran pada Sampel B, misalnya "Mengapa '
                'cairan di dalam Sampel B bisa bocor keluar?".',
          ),
        ],
      ),
      MissionContent(
        code: 'MISI-3',
        title: 'Misi 3 — Perbandingan Lapisan Terluar',
        sampleRef: 'SAMPLE_AB',
        orderNumber: 3,
        briefing:
            'Bandingkan lapisan terluar kedua sampel secara berdampingan dan '
            'catat perbedaannya pada logbook Misi 3.',
        logbookPrompts: [
          'Perbedaan lapisan terluar Sampel A dan B',
          'Bahan penyusun dinding sel Sampel A',
          'Kondisi lapisan terluar tiap sampel',
          'Dampak perbedaan struktur terhadap ketahanan sel',
        ],
        sequence: MissionSequences.misi3,
        intentRules: [
          // PDF Misi 3: tidak hancur / perbedaan / kenapa bentuk tetap
          // e.g. "Kenapa Sampel A tidak hancur sekempes Sampel B"
          IntentRule(
            code: 'compare_sample_durability',
            keywords: {'sampel a'},
            anyKeywords: {
              'tidak hancur',
              'tidak kempes',
              'tidak hancur sekempes',
              'perbedaan',
              'perbandingan',
              'bentuk tetap',
              'bentuknya tetap',
              'tetap kaku',
              'dinding sel',
            },
            response:
                'Bandingkan ketahanan kedua sampel. Perhatikan dinding sel '
                'Sampel A yang menahan tekanan, lalu catat perbedaannya di '
                'logbook tanpa mengarang label provisional.',
            sequenceCode: 'SEQ-MISI-3',
            missionNumber: 3,
          ),
          IntentRule(
            code: 'compare_outer_layers',
            keywords: {'bandingkan', 'lapisan'},
            response:
                'Bandingkan lapisan terluar kedua sampel. Perhatikan dinding '
                'sel pada Sampel A dan bandingkan dengan membran Sampel B, '
                'lalu catat perbedaannya di logbook.',
            sequenceCode: 'SEQ-MISI-3',
            missionNumber: 3,
          ),
          IntentRule(
            code: 'request_hint_m3',
            keywords: {'petunjuk', 'perbedaan'},
            response:
                'Coba tanyakan kenapa Sampel A tidak hancur seperti Sampel B, '
                'atau apa perbedaannya.',
          ),
        ],
      ),
    ],
    stations: [
      StationContent(
        code: 'POS-1',
        title: 'POS 1 — Identifikasi Struktur',
        pin: '1111',
        markerCode: 'MARKER-POS-1',
        questions: [
          QuestionContent(
            code: 'POS1-Q1',
            text: 'Sampel manakah yang memiliki dinding sel?',
            kind: QuestionKind.objective,
            maxScore: 10,
            correctAnswer: 'Sampel A',
          ),
          QuestionContent(
            code: 'POS1-Q2',
            text:
                'Jelaskan fungsi dinding sel berdasarkan pengamatan kelompokmu.',
            kind: QuestionKind.essay,
            maxScore: 5,
            rubric: 'Menyebut pelindung/penyokong bentuk sel.',
          ),
        ],
      ),
      StationContent(
        code: 'POS-2',
        title: 'POS 2 — Analisis Kerusakan',
        pin: '2222',
        markerCode: 'MARKER-POS-2',
        questions: [
          QuestionContent(
            code: 'POS2-Q1',
            text: 'Bagian sel Sampel B yang mengalami kerusakan adalah…',
            kind: QuestionKind.objective,
            maxScore: 10,
            correctAnswer: 'Membran',
          ),
          QuestionContent(
            code: 'POS2-Q2',
            text: 'Uraikan dampak kerusakan membran terhadap isi sel.',
            kind: QuestionKind.essay,
            maxScore: 10,
            rubric: 'Menyebut kebocoran isi sel/kehilangan homeostasis.',
          ),
        ],
      ),
      StationContent(
        code: 'POS-3',
        title: 'POS 3 — Kesimpulan Forensik',
        pin: '3333',
        markerCode: 'MARKER-POS-3',
        questions: [
          QuestionContent(
            code: 'POS3-Q1',
            text: 'Sampel A paling tepat diidentifikasi sebagai sel…',
            kind: QuestionKind.objective,
            maxScore: 10,
            correctAnswer: 'Tumbuhan',
          ),
          QuestionContent(
            code: 'POS3-Q2',
            text:
                'Tuliskan hipotesis akhir kelompok berdasarkan seluruh bukti.',
            kind: QuestionKind.essay,
            maxScore: 5,
            rubric: 'Hipotesis berbasis bukti dinding sel dan membran.',
          ),
        ],
      ),
    ],
  );
}

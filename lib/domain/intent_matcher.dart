/// Deterministic, offline intent matcher for the investigation assistant (E4-02).
///
/// Two responsibilities:
///  1. Rule matching — curated [IntentRule.response] text is returned so the
///     assistant never invents biology (E4-03 / E0-08).
///  2. Mission classification — maps a student's *question* to Misi 1/2/3 (or
///     none) using the Bahasa Indonesia trigger keywords from the scenario PDF
///     (`CELL FORENSIC (3).pdf`, SCENE 2 "AR-AI Trigger Codes").
///
/// Provisional biology labels (Organel X/Y, membran 1/2) never receive invented
/// facts and never trigger mission progress.
///
/// This matcher is pure/side-effect free. Mission classification is only ever
/// meaningful for student questions — callers must NOT run it on join, group,
/// or placement events (those never carry a question).
class IntentRule {
  const IntentRule({
    required this.code,
    required this.keywords,
    required this.response,
    this.anyKeywords = const <String>{},
    this.sequenceCode,
    this.missionNumber,
  });

  final String code;

  /// Required keywords — ALL must be present (AND).
  final Set<String> keywords;

  /// Optional synonym group — when non-empty, AT LEAST ONE must be present
  /// (OR). Lets a rule fire on "Sampel B + (bocor|cairan|membran)" without
  /// forcing a single fixed term. Empty = no OR constraint.
  final Set<String> anyKeywords;

  final String response;
  final String? sequenceCode;

  /// Optional explicit mission (1–3) this rule belongs to. When set it takes
  /// precedence over keyword-based [IntentMatcher.classifyMission].
  final int? missionNumber;

  /// Whether [text] satisfies both the AND ([keywords]) and OR ([anyKeywords])
  /// constraints. [text] is expected to be already normalized (lowercased).
  bool matches(String text) {
    if (!keywords.every(text.contains)) return false;
    if (anyKeywords.isNotEmpty && !anyKeywords.any(text.contains)) return false;
    return true;
  }
}

class IntentMatch {
  const IntentMatch({
    required this.intentCode,
    required this.response,
    this.sequenceCode,
    this.missionNumber,
  });

  final String intentCode;
  final String response;
  final String? sequenceCode;

  /// The mission (1/2/3) this question maps to, or `null` for none/unknown.
  ///
  /// `null` means "no mission progress change" — the consumer
  /// (mission_screen / sequence_engine) must not advance any mission.
  final int? missionNumber;

  /// Whether this question resolved to a concrete mission (1/2/3).
  bool get hasMission => missionNumber != null;
}

class IntentMatcher {
  const IntentMatcher(this.rules);

  /// FR-032 off-topic / unrecognized questions (never invent facts).
  static const unknownIntent = 'off_topic';
  static const unknownResponse =
      'Pertanyaan belum dikenali. Coba tanyakan objek yang ingin diamati.';

  static const provisionalIntent = 'provisional_label';
  static const provisionalResponse =
      'Label itu masih provisional dan belum diverifikasi untuk penilaian. '
      'Amati struktur yang terlihat pada scene, lalu catat pengamatanmu di '
      'logbook tanpa mengarang nama organel/membran bernomor.';

  static const offTopicIntent = 'off_topic';
  static const offTopicResponse =
      'Pertanyaan di luar topik investigasi. Fokus ke sampel, organel, '
      'membran, atau bandingkan lapisan terluar.';

  /// Phrases that must never get invented biology answers.
  static const provisionalPhrases = <String>{
    'organel x',
    'organel y',
    'membran 1',
    'membran 2',
    'bagian membran 1',
    'bagian membran 2',
  };

  static const offTopicPhrases = <String>{
    'cuaca',
    'suhu ruangan',
    'siapa presiden',
    'skor bola',
  };

  // --- Mission classification keyword sets (PDF SCENE 2) -------------------

  /// Tokens that name Sampel A (sel tumbuhan).
  static const sampleATokens = <String>{'sampel a', 'sample a'};

  /// Tokens that name Sampel B (sel hewan).
  static const sampleBTokens = <String>{'sampel b', 'sample b'};

  /// Misi 1 context: struktur/fungsi organel Sampel A yang rusak.
  static const mission1Context = <String>{
    'organel',
    'kloroplas',
    'vakuola',
    'nukleus',
    'rusak',
    'kerusakan',
    'sekarat',
  };

  /// Misi 2 context: kondisi membran / kebocoran cairan Sampel B.
  static const mission2Context = <String>{
    'membran',
    'bocor',
    'cairan',
    'fosfolipid',
    'bilayer',
    'permeabel',
    'hidrofobik',
  };

  /// Misi 3 signals: perbedaan sampel / Sampel A tidak hancur / bentuk tetap.
  static const mission3Signals = <String>{
    'tidak hancur',
    'tidak rusak',
    'tidak kempes',
    'tidak hancur sekempes',
    'perbedaan',
    'perbandingan',
    'berbeda',
    'bandingkan',
    'dibandingkan',
    'membandingkan',
    'dibanding',
    'bentuknya tetap',
    'bentuk tetap',
    'tetap kaku',
    'masih kaku',
    'kenapa bentuk',
    'dinding sel',
  };

  final List<IntentRule> rules;

  /// Classifies a student [input] question into Misi 1/2/3, or `null`.
  ///
  /// Deterministic mapping from the PDF trigger codes:
  ///  - Misi 1: Sampel A + konteks rusak/organel (kloroplas/vakuola/…).
  ///  - Misi 2: Sampel B + bocor/cairan/membran.
  ///  - Misi 3: Sampel A tidak hancur / perbedaan / kenapa bentuknya tetap
  ///            (juga saat kedua sampel disebut bersama = perbandingan).
  ///  - none : tidak ada perubahan progres misi.
  ///
  /// Misi 3 is evaluated first so comparison questions that mention both
  /// samples are not miscounted as Misi 1 or 2.
  static int? classifyMission(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return null;

    // Provisional / off-topic never move mission progress.
    if (provisionalPhrases.any(text.contains)) return null;
    if (offTopicPhrases.any(text.contains)) return null;

    final hasSampleA = sampleATokens.any(text.contains);
    final hasSampleB = sampleBTokens.any(text.contains);

    // Misi 3 — perbandingan / perbedaan / Sampel A tidak hancur.
    final comparesBothSamples = hasSampleA && hasSampleB;
    if (comparesBothSamples || mission3Signals.any(text.contains)) {
      return 3;
    }

    // Misi 1 — Sampel A + konteks organel/rusak.
    if (hasSampleA && mission1Context.any(text.contains)) {
      return 1;
    }

    // Misi 2 — Sampel B + bocor/cairan/membran.
    if (hasSampleB && mission2Context.any(text.contains)) {
      return 2;
    }

    return null;
  }

  IntentMatch match(String input) {
    final normalized = input.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const IntentMatch(
        intentCode: unknownIntent,
        response: unknownResponse,
      );
    }

    if (provisionalPhrases.any(normalized.contains)) {
      return const IntentMatch(
        intentCode: provisionalIntent,
        response: provisionalResponse,
      );
    }

    if (offTopicPhrases.any(normalized.contains)) {
      return const IntentMatch(
        intentCode: offTopicIntent,
        response: offTopicResponse,
      );
    }

    final mission = classifyMission(normalized);

    final matches = rules.where((rule) => rule.matches(normalized));

    if (matches.length != 1) {
      return IntentMatch(
        intentCode: unknownIntent,
        response: unknownResponse,
        // PDF SCENE 2: keyword→mission alone must still drive AR offline.
        sequenceCode: sequenceCodeForMission(mission),
        missionNumber: mission,
      );
    }

    final rule = matches.single;
    final resolvedMission = rule.missionNumber ?? mission;
    return IntentMatch(
      intentCode: rule.code,
      response: rule.response,
      sequenceCode: rule.sequenceCode ?? sequenceCodeForMission(resolvedMission),
      missionNumber: resolvedMission,
    );
  }

  /// Canonical sequence code for mission 1/2/3 (`SEQ-MISI-N`), else `null`.
  static String? sequenceCodeForMission(int? missionNumber) =>
      switch (missionNumber) {
        1 || 2 || 3 => 'SEQ-MISI-$missionNumber',
        _ => null,
      };
}

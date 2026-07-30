import 'package:flutter/foundation.dart';

import '../../../domain/ai/ai_assistant_client.dart';
import '../../../domain/ai/ai_assistant_response.dart';
import '../../../domain/ai/ar_action_whitelist.dart';
import '../../../domain/intent_matcher.dart';

/// Penulis sebuah pesan pada percakapan asisten.
enum ChatAuthor { user, assistant }

/// Satu gelembung pesan dalam riwayat percakapan.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    this.sequenceCode,
    this.arAction,
  });

  final ChatAuthor author;
  final String text;

  /// Kode urutan animasi/AR opsional yang berasal dari [IntentMatch].
  final String? sequenceCode;

  /// Whitelisted AR action from AI proxy (E11); may be `none` / null.
  final String? arAction;
}

/// State ringan (MVVM) untuk layar chat asisten.
///
/// Offline-first: [IntentMatcher] always answers without network.
/// When [aiClient] is set, the OpenAI-compatible proxy is tried first; on
/// failure the matcher is used. Never stores API keys.
///
/// Offline / IntentMatcher hits with a [IntentMatch.sequenceCode] invoke
/// [onSequenceCode] so [SequenceEngine] can start mission AR without Supabase.
class AssistantViewModel extends ChangeNotifier {
  AssistantViewModel({
    required IntentMatcher matcher,
    this.aiClient,
    this.missionNumber = 1,
    this.onArAction,
    this.onSequenceCode,
  }) : _matcher = matcher;

  final IntentMatcher _matcher;

  /// Optional secure proxy (Supabase Edge Function). Null → matcher only.
  final AiAssistantClient? aiClient;

  /// Active mission 1–3 for whitelist / structured AI prompts.
  int missionNumber;

  /// Invoked when a validated non-`none` AR action should run on the scene.
  final void Function(String arAction)? onArAction;

  /// Invoked when IntentMatcher yields a mission sequence code (`SEQ-MISI-N`).
  ///
  /// This is the offline question → AR bridge (no Supabase / AI proxy required).
  final void Function(String sequenceCode)? onSequenceCode;

  final List<ChatMessage> _messages = <ChatMessage>[];
  bool _busy = false;
  bool _lastReplyUsedCloud = false;
  bool _cloudUnavailable = false;

  /// Riwayat percakapan yang tidak dapat dimutasi dari luar.
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool get hasMessages => _messages.isNotEmpty;

  bool get isBusy => _busy;

  /// Whether the most recent assistant turn came from the cloud proxy.
  bool get lastReplyUsedCloud => _lastReplyUsedCloud;

  /// True after a cloud attempt failed (Edge secret / network / parse).
  bool get cloudUnavailable => _cloudUnavailable;

  /// Cloud proxy is wired (may still fail at request time).
  bool get cloudConfigured => aiClient != null;

  /// Last resolved AR action from the most recent assistant turn (tests).
  String? lastArAction;

  /// Last IntentMatcher sequence code from the most recent local turn (tests).
  String? lastSequenceCode;

  /// Mengirim pertanyaan pengguna lalu menambahkan balasan asisten.
  ///
  /// Input kosong/berisi spasi diabaikan agar riwayat tetap bersih.
  /// When [aiClient] is null this completes synchronously (no await before
  /// notify) so existing widget tests stay green with a single pump.
  Future<void> send(String input) async {
    final question = input.trim();
    if (question.isEmpty || _busy) {
      return;
    }

    _messages.add(ChatMessage(author: ChatAuthor.user, text: question));
    notifyListeners();

    // Always block provisional inventing locally first (E0-08 / E4-03).
    // Note: IntentMatcher.unknownIntent == 'off_topic' (same code string), so
    // only short-circuit explicit provisional / off-topic *phrases* — not
    // unrecognized questions, which should still try the AI proxy.
    final normalized = question.toLowerCase();
    final local = _matcher.match(question);
    final isProvisional =
        IntentMatcher.provisionalPhrases.any(normalized.contains);
    final isExplicitOffTopic =
        IntentMatcher.offTopicPhrases.any(normalized.contains);
    if (isProvisional || isExplicitOffTopic) {
      _pushAssistant(
        text: local.response,
        sequenceCode: null,
        arAction: ArActionWhitelist.none,
        fromCloud: false,
      );
      return;
    }

    final client = aiClient;
    if (client == null) {
      _cloudUnavailable = true;
      _pushAssistant(
        text: local.response,
        sequenceCode: local.sequenceCode,
        arAction: ArActionWhitelist.none,
        fromCloud: false,
      );
      return;
    }

    _busy = true;
    notifyListeners();
    AiAssistantResponse? ai;
    try {
      ai = await client.ask(message: question, mission: missionNumber);
    } catch (error, stack) {
      logAiAssistantFailure(error, stack);
      _cloudUnavailable = true;
    } finally {
      _busy = false;
    }

    if (ai != null) {
      _cloudUnavailable = false;
      _applyAiResponse(ai);
    } else {
      // Offline-equivalent fallback: IntentMatch.sequenceCode drives AR.
      _pushAssistant(
        text:
            '${local.response}\n\n'
            '(Asisten cloud tidak tersedia — petunjuk lokal.)',
        sequenceCode: local.sequenceCode,
        arAction: ArActionWhitelist.none,
        fromCloud: false,
      );
    }
  }

  void _applyAiResponse(AiAssistantResponse ai) {
    // Mission mismatch: still show message, but strip AR action.
    final missionOk = ai.mission == missionNumber || ai.mission == 0;
    final action = missionOk
        ? ai.resolvedAction(activeMission: missionNumber)
        : ArActionWhitelist.none;

    _pushAssistant(
      text: ai.message,
      arAction: action,
      fromCloud: true,
    );
  }

  void _pushAssistant({
    required String text,
    String? sequenceCode,
    String? arAction,
    bool fromCloud = false,
  }) {
    _lastReplyUsedCloud = fromCloud;
    final action = arAction ?? ArActionWhitelist.none;
    lastArAction = action;
    lastSequenceCode = sequenceCode;
    _messages.add(
      ChatMessage(
        author: ChatAuthor.assistant,
        text: text,
        sequenceCode: sequenceCode,
        arAction: action,
      ),
    );
    notifyListeners();
    if (action != ArActionWhitelist.none) {
      // Never let AR side-effects break the chat reply path.
      try {
        onArAction?.call(action);
      } catch (error, stack) {
        logAiAssistantFailure(error, stack);
      }
    }
    final seq = sequenceCode?.trim();
    if (seq != null && seq.isNotEmpty) {
      try {
        onSequenceCode?.call(seq);
      } catch (error, stack) {
        logAiAssistantFailure(error, stack);
      }
    }
  }
}

/// Contoh aturan intent berbahasa Indonesia untuk demo dan pengujian.
///
/// Tidak menyebut Organel X/Y atau membran 1/2 sebagai fakta (E4-03).
const List<IntentRule> demoIntentRules = <IntentRule>[
  IntentRule(
    code: 'inspect_sample_a_organel',
    keywords: {'sampel a', 'organel'},
    response:
        'Perhatikan organel tervalidasi pada Sampel A (kloroplas, vakuola, '
        'nukleus). Catat gejala yang terlihat di logbook.',
    sequenceCode: 'SEQ-MISI-1',
  ),
  IntentRule(
    code: 'inspect_sample_b_membrane',
    keywords: {'sampel b', 'membran'},
    response:
        'Amati kondisi membran Sampel B secara keseluruhan. Catat bagian yang '
        'tampak rusak tanpa mengarang nomor membran.',
    sequenceCode: 'SEQ-MISI-2',
  ),
  IntentRule(
    code: 'explain_membrane',
    keywords: {'fungsi', 'membran'},
    response:
        'Membran sel mengatur keluar-masuk zat. Hubungkan dengan apa yang '
        'terlihat pada scene, lalu tulis di logbook.',
  ),
  IntentRule(
    code: 'request_hint',
    keywords: {'petunjuk'},
    response:
        'Coba tanyakan organel Sampel A atau membran Sampel B. Hindari label '
        'provisional seperti Organel X/Y.',
  ),
];

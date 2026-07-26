import 'package:cell_forensic/domain/ai/ar_action_whitelist.dart';

/// Structured JSON from the OpenAI-compatible proxy (E11).
class AiAssistantResponse {
  const AiAssistantResponse({
    required this.message,
    required this.intent,
    required this.mission,
    required this.target,
    required this.arAction,
    required this.confidence,
  });

  final String message;
  final String intent;
  final int mission;
  final String target;
  final String arAction;
  final double confidence;

  /// Parsed + whitelist-sanitized action (may be `none`).
  String resolvedAction({required int activeMission}) {
    return ArActionWhitelist.resolve(
      arAction: arAction,
      missionNumber: activeMission,
      confidence: confidence,
    );
  }

  static AiAssistantResponse? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final message = map['message']?.toString().trim() ?? '';
    if (message.isEmpty) return null;

    final missionRaw = map['mission'];
    final mission = missionRaw is int
        ? missionRaw
        : int.tryParse(missionRaw?.toString() ?? '') ?? 0;

    final confidenceRaw = map['confidence'];
    final confidence = confidenceRaw is num
        ? confidenceRaw.toDouble()
        : double.tryParse(confidenceRaw?.toString() ?? '') ?? 0;

    return AiAssistantResponse(
      message: message,
      intent: map['intent']?.toString() ?? 'unknown',
      mission: mission,
      target: map['target']?.toString() ?? '',
      arAction: ArActionWhitelist.sanitize(map['ar_action']?.toString()),
      confidence: confidence.clamp(0.0, 1.0),
    );
  }
}

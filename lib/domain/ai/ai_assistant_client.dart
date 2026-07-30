import 'dart:developer' as developer;

import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/domain/ai/ai_assistant_response.dart';
import 'package:cell_forensic/domain/intent_matcher.dart';

/// Secure proxy client for the OpenAI-compatible assistant (E11).
///
/// Calls Supabase Edge Function `ai-assistant`. Never holds `OPENAI_API_KEY`.
/// On any failure, callers should fall back to [IntentMatcher].
abstract interface class AiAssistantClient {
  Future<AiAssistantResponse> ask({
    required String message,
    required int mission,
  });
}

/// Live client via `supabase.functions.invoke('ai-assistant')`.
class SupabaseAiAssistantClient implements AiAssistantClient {
  const SupabaseAiAssistantClient();

  static const functionName = 'ai-assistant';

  @override
  Future<AiAssistantResponse> ask({
    required String message,
    required int mission,
  }) async {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      throw StateError('Supabase belum dikonfigurasi');
    }

    final response = await client.functions.invoke(
      functionName,
      body: {
        'message': message,
        'mission': mission,
      },
    );

    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw StateError(data['error'].toString());
    }
    final parsed = AiAssistantResponse.tryParse(data);
    if (parsed == null) {
      throw FormatException('Respons AI tidak valid');
    }

    // Guard: never invent facts for provisional labels.
    final lower = message.toLowerCase();
    if (IntentMatcher.provisionalPhrases.any(lower.contains)) {
      throw StateError('Provisional label — gunakan IntentMatcher');
    }

    return parsed;
  }
}

/// Test double that returns a fixed response or throws.
class FakeAiAssistantClient implements AiAssistantClient {
  FakeAiAssistantClient({this.response, this.error});

  AiAssistantResponse? response;
  Object? error;

  int callCount = 0;

  @override
  Future<AiAssistantResponse> ask({
    required String message,
    required int mission,
  }) async {
    callCount++;
    final err = error;
    if (err != null) throw err;
    final value = response;
    if (value == null) {
      throw StateError('FakeAiAssistantClient: no response configured');
    }
    return value;
  }
}

/// Logs AI failures without leaking secrets or raw keys.
void logAiAssistantFailure(Object error, StackTrace stack) {
  developer.log(
    'AI assistant proxy gagal — fallback IntentMatcher',
    name: 'AiAssistant',
    error: error.runtimeType.toString(),
    stackTrace: stack,
  );
}

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:cell_forensic/core/config/ai_config.dart';
import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/domain/ai/ai_assistant_response.dart';
import 'package:cell_forensic/domain/intent_matcher.dart';

/// Secure / Direct client for the OpenAI-compatible assistant (E11).
///
/// On any failure, callers should fall back to [IntentMatcher].
abstract interface class AiAssistantClient {
  Future<AiAssistantResponse> ask({
    required String message,
    required int mission,
  });
}

/// Direct client calling OpenAI-compatible `/chat/completions` API using
/// environment variables (`AiConfig.apiKey`, `AiConfig.baseUrl`, `AiConfig.model`).
class DirectOpenAiAssistantClient implements AiAssistantClient {
  DirectOpenAiAssistantClient({
    http.Client? httpClient,
    this.apiKeyOverride,
    this.baseUrlOverride,
    this.modelOverride,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final String? apiKeyOverride;
  final String? baseUrlOverride;
  final String? modelOverride;

  static const Set<String> allowedActions = <String>{
    'none',
    'focus_sample_a',
    'focus_sample_b',
    'highlight_chloroplast',
    'show_damaged_chloroplast',
    'show_vacuole_damage',
    'focus_membrane',
    'show_membrane_damage',
    'show_water_leak',
    'compare_samples',
    'highlight_cell_wall',
    'show_force_arrows',
    'reset_scene',
  };

  @override
  Future<AiAssistantResponse> ask({
    required String message,
    required int mission,
  }) async {
    final apiKey = apiKeyOverride ?? AiConfig.apiKey;
    if (apiKey.isEmpty) {
      throw StateError('OPENAI_API_KEY belum dikonfigurasi di environment');
    }

    final baseUrl = (baseUrlOverride ?? AiConfig.baseUrl).replaceAll(RegExp(r'/$'), '');
    final model = modelOverride ?? AiConfig.model;

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw FormatException('message wajib diisi');
    }
    if (!<int>[1, 2, 3].contains(mission)) {
      throw FormatException('mission harus 1, 2, atau 3');
    }

    // Guard: block provisional inventing at client boundary.
    final lower = trimmedMessage.toLowerCase();
    if (IntentMatcher.provisionalPhrases.any(lower.contains)) {
      return AiAssistantResponse(
        message:
            'Label itu masih provisional dan belum diverifikasi untuk penilaian. '
            'Amati struktur yang terlihat pada scene, lalu catat pengamatanmu di '
            'logbook tanpa mengarang nama organel/membran bernomor.',
        intent: 'provisional_label',
        mission: mission,
        target: '',
        arAction: 'none',
        confidence: 1.0,
      );
    }

    final systemPrompt = <String>[
      'Kamu asisten investigasi Cell Forensic (Bahasa Indonesia).',
      'Jawab singkat dan bantu siswa mengamati scene AR.',
      'JANGAN mengarang fakta tentang Organel X/Y atau membran 1/2.',
      'Balas HANYA JSON valid (tanpa markdown) dengan skema:',
      '{"message":"...","intent":"...","mission":$mission,"target":"...","ar_action":"...","confidence":0.0}',
      'ar_action whitelist: ${allowedActions.join(", ")}',
      'Pilih ar_action yang cocok dengan misi $mission; jika ragu pakai none.',
      'confidence 0–1. Jangan sertakan API key atau rahasia.',
    ].join(' ');

    final uri = Uri.parse('$baseUrl/chat/completions');
    final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(<String, dynamic>{
          'model': model,
          'temperature': 0.2,
          'response_format': <String, String>{'type': 'json_object'},
          'messages': <Map<String, String>>[
            <String, String>{'role': 'system', 'content': systemPrompt},
            <String, String>{'role': 'user', 'content': trimmedMessage},
          ],
        }),
      );
    } catch (e) {
      throw StateError('Gagal menghubungi API AI: $e');
    }

    if (response.statusCode != 200) {
      throw StateError('Upstream AI error (HTTP ${response.statusCode})');
    }

    final responseText = response.body.trim();
    String? rawContent;

    if (responseText.startsWith('data:') || responseText.contains('\ndata:')) {
      final buffer = StringBuffer();
      final lines = responseText.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final dataStr = trimmed.substring(5).trim();
        if (dataStr == '[DONE]') continue;
        try {
          final chunk = jsonDecode(dataStr);
          if (chunk is Map) {
            final choices = chunk['choices'];
            if (choices is List && choices.isNotEmpty) {
              final first = choices.first;
              if (first is Map) {
                final delta = first['delta'];
                if (delta is Map) {
                  final text = delta['content']?.toString() ?? '';
                  buffer.write(text);
                }
              }
            }
          }
        } catch (_) {}
      }
      rawContent = buffer.toString().trim();
    } else {
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(responseText) as Map<String, dynamic>;
      } catch (e) {
        throw FormatException('Respons AI bukan JSON yang valid');
      }

      final choices = body['choices'];
      if (choices is! List || choices.isEmpty) {
        throw FormatException('Respons AI tidak mengandung pilihan jawaban');
      }

      final firstChoice = choices.first;
      if (firstChoice is! Map) {
        throw FormatException('Format pilihan jawaban AI tidak sesuai');
      }

      rawContent = firstChoice['message']?['content']?.toString();
    }

    Object? rawMap;
    if (rawContent != null && rawContent.isNotEmpty) {
      var text = rawContent.trim();
      if (text.startsWith('```')) {
        text = text
            .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
            .replaceFirst(RegExp(r'\s*```$'), '');
      }
      try {
        rawMap = jsonDecode(text);
      } catch (_) {
        rawMap = null;
      }
    }

    final parsed = AiAssistantResponse.tryParse(rawMap);
    if (parsed == null) {
      throw FormatException('Respons model AI tidak dapat diparse');
    }

    return parsed;
  }
}

/// Legacy client via `supabase.functions.invoke('ai-assistant')`.
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

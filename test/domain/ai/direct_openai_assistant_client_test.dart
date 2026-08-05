import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

import 'package:cell_forensic/domain/ai/ai_assistant_client.dart';

void main() {
  group('DirectOpenAiAssistantClient', () {
    test('blocks provisional phrases locally without network call', () async {
      var called = false;
      final mockClient = http_testing.MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });

      final client = DirectOpenAiAssistantClient(
        httpClient: mockClient,
        apiKeyOverride: 'test-key',
      );

      final response = await client.ask(message: 'Apakah ini Organel X?', mission: 1);

      expect(called, isFalse);
      expect(response.intent, 'provisional_label');
      expect(response.arAction, 'none');
    });

    test('parses valid OpenAI completion response correctly', () async {
      Uri? requestUri;
      Map<String, String>? requestHeaders;
      Map<String, dynamic>? requestBody;

      final mockClient = http_testing.MockClient((request) async {
        requestUri = request.url;
        requestHeaders = request.headers;
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;

        final jsonResponse = {
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'message': 'Bandingkan kloroplas dan vakuola',
                  'intent': 'compare_samples',
                  'mission': 1,
                  'target': 'sample_a',
                  'ar_action': 'compare_samples',
                  'confidence': 0.95,
                }),
              },
            },
          ],
        };
        return http.Response(jsonEncode(jsonResponse), 200);
      });

      final client = DirectOpenAiAssistantClient(
        httpClient: mockClient,
        apiKeyOverride: 'sk-test12345',
        baseUrlOverride: 'https://api.test.com/v1',
        modelOverride: 'test-model',
      );

      final result = await client.ask(message: 'Bandingkan sampel A dan B', mission: 1);

      expect(requestUri.toString(), 'https://api.test.com/v1/chat/completions');
      expect(requestHeaders?['Authorization'], 'Bearer sk-test12345');
      expect(requestBody?['model'], 'test-model');
      expect(result.message, 'Bandingkan kloroplas dan vakuola');
      expect(result.arAction, 'compare_samples');
      expect(result.confidence, 0.95);
    });

    test('throws StateError on HTTP error status', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Forbidden', 403);
      });

      final client = DirectOpenAiAssistantClient(
        httpClient: mockClient,
        apiKeyOverride: 'test-key',
      );

      expect(
        () => client.ask(message: 'Pertanyaan tes', mission: 1),
        throwsA(isA<StateError>()),
      );
    });
  });
}

/// Configuration for direct OpenAI-compatible AI assistant integration.
///
/// Values are supplied at build or run time via `--dart-define` or `--dart-define-from-file=.env`:
/// ```bash
/// flutter run --dart-define-from-file=.env
/// ```
class AiConfig {
  const AiConfig._();

  /// OpenAI API key (secret).
  static const apiKey = String.fromEnvironment('OPENAI_API_KEY');

  /// Base URL for the OpenAI-compatible API.
  static const baseUrl = String.fromEnvironment(
    'OPENAI_BASE_URL',
    defaultValue: 'https://api.arklabs.biz.id/v1',
  );

  /// Default model name for completions.
  static const model = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'cell-forensik',
  );

  /// True if an API key has been supplied.
  static bool get isConfigured => apiKey.isNotEmpty;
}

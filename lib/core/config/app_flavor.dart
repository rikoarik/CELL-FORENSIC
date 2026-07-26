/// Build-time environment selection (E1-06).
///
/// ```bash
/// flutter run --dart-define=APP_FLAVOR=dev
/// flutter run --dart-define=APP_FLAVOR=staging
/// flutter run --dart-define=APP_FLAVOR=prod
/// ```
enum AppFlavor {
  dev,
  staging,
  prod;

  static const _raw = String.fromEnvironment('APP_FLAVOR', defaultValue: 'dev');

  static AppFlavor get current {
    return AppFlavor.values.firstWhere(
      (f) => f.name == _raw.toLowerCase(),
      orElse: () => AppFlavor.dev,
    );
  }

  bool get isProd => this == AppFlavor.prod;

  /// Human label for debug banners / about screens.
  String get label => switch (this) {
    AppFlavor.dev => 'Development',
    AppFlavor.staging => 'Staging',
    AppFlavor.prod => 'Production',
  };
}

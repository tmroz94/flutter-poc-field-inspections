import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BackendMode { http, fake }

/// Where data comes from. Set with `--dart-define`:
/// - `BACKEND=auto|http|fake` (default auto: use the mock server if it answers, else the in-app fake)
/// - `API_URL=http://host:8080/api` (default: localhost; 10.0.2.2 on the Android emulator)
@immutable
class BackendConfig {
  const BackendConfig({required this.mode, required this.baseUrl});

  final BackendMode mode;
  final String baseUrl;

  static const _requested = String.fromEnvironment('BACKEND', defaultValue: 'auto');
  static const _apiUrl = String.fromEnvironment('API_URL');

  static String get defaultBaseUrl {
    if (_apiUrl.isNotEmpty) return _apiUrl;
    // The Android emulator reaches the host machine at 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8080/api';
    return 'http://localhost:8080/api';
  }

  /// Resolves `auto` by probing `/health` with a short timeout.
  static Future<BackendConfig> resolve() async {
    final url = defaultBaseUrl;
    switch (_requested) {
      case 'fake':
        return BackendConfig(mode: BackendMode.fake, baseUrl: url);
      case 'http':
        return BackendConfig(mode: BackendMode.http, baseUrl: url);
    }
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(milliseconds: 1500), receiveTimeout: const Duration(milliseconds: 1500)));
      final r = await dio.get<Object?>('$url/health');
      if (r.statusCode == 200) return BackendConfig(mode: BackendMode.http, baseUrl: url);
    } on DioException {
      // Fall through to the fake.
    }
    return BackendConfig(mode: BackendMode.fake, baseUrl: url);
  }
}

/// Overridden in `main` with the resolved config; tests use the fake.
final backendConfigProvider = Provider<BackendConfig>((ref) => const BackendConfig(mode: BackendMode.fake, baseUrl: ''));

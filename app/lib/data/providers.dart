import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mock_data/mock_data.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_repository.dart';
import 'api/api_client.dart';
import 'api/backend_config.dart';
import 'repositories/inspections_repository.dart';

/// The in-app fake backend (used when the mock server isn't reachable).
final mockDatabaseProvider = Provider<MockDatabase>((ref) => MockDatabase());

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(backendConfigProvider);
  return ApiClient(
    baseUrl: config.baseUrl,
    token: () => ref.read(authControllerProvider).session?.token,
    // A rejected token ends the session; the router then shows sign-in.
    onUnauthorized: () => ref.read(authControllerProvider.notifier).signOut(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return switch (ref.watch(backendConfigProvider).mode) {
    BackendMode.http => HttpAuthRepository(ref.watch(apiClientProvider)),
    BackendMode.fake => FakeAuthRepository(ref.watch(mockDatabaseProvider)),
  };
});

final inspectionsRepositoryProvider = Provider<InspectionsRepository>((ref) {
  return switch (ref.watch(backendConfigProvider).mode) {
    BackendMode.http => HttpInspectionsRepository(ref.watch(apiClientProvider)),
    BackendMode.fake => FakeInspectionsRepository(ref.watch(mockDatabaseProvider)),
  };
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mock_data/mock_data.dart';

import '../features/auth/auth_repository.dart';

/// The in-app fake backend. M1 adds the HTTP implementation and picks one at
/// start-up depending on whether the mock server answers.
final mockDatabaseProvider = Provider<MockDatabase>((ref) => MockDatabase());

final authRepositoryProvider = Provider<AuthRepository>((ref) => FakeAuthRepository(ref.watch(mockDatabaseProvider)));

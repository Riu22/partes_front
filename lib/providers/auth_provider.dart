import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/perfil.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final apiServiceProvider = Provider((ref) => ApiService());

class AuthNotifier extends AsyncNotifier<Perfil?> {
  @override
  Future<Perfil?> build() async {
    final token = await ref.read(authServiceProvider).getToken();
    if (token == null) return null;
    try {
      final data = await ref.read(apiServiceProvider).getMyProfile();
      return Perfil.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncLoading();
    final token = await ref.read(authServiceProvider).login(email, password);
    if (token == null) {
      state = const AsyncData(null);
      return false;
    }
    final data = await ref.read(apiServiceProvider).getMyProfile();
    state = AsyncData(Perfil.fromJson(data));
    return true;
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, Perfil?>(
  AuthNotifier.new,
);

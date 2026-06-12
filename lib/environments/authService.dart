import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient supabase;

  AuthService(this.supabase);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {

    final authResponse =
    await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = authResponse.user;

    if (user == null) {
      throw Exception('Credenciales inválidas');
    }

    final manager = await supabase
        .from('administradores_gestores')
        .select()
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (manager != null) {
      return {
        'type': 'manager',
        'profile': manager,
      };
    }

    final intern = await supabase
        .from('practicantes')
        .select()
        .eq('auth_user_id', user.id)
        .maybeSingle();

    if (intern != null) {
      return {
        'type': 'intern',
        'profile': intern,
      };
    }

    throw Exception('Usuario autenticado sin perfil asociado',);
  }
}
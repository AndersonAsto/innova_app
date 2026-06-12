import 'package:flutter/material.dart';
import 'package:innova/login/authGate.dart';
import 'package:innova/login/loginScreen.dart';
import 'package:innova/main.dart';
import 'package:innova/navigation/internNavigationScreen.dart';
import 'package:innova/navigation/managerNavigationScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadSession();
    });
  }

  Future<void> loadSession() async {

    final session = supabase.auth.currentSession;

    if (session == null) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );

      return;
    }

    final userId = session.user.id;

    final manager = await supabase
        .from('administradores_gestores')
        .select()
        .eq('auth_user_id', userId)
        .maybeSingle();

    if (manager != null) {
      SessionService.profile = manager;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ManagerNavigationScreen(
            profile: manager,
          ),
        ),
      );

      return;
    }

    final intern = await supabase
        .from('practicantes')
        .select()
        .eq('auth_user_id', userId)
        .maybeSingle();

    if (intern != null) {
      SessionService.profile = intern;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InternNavigationScreen(
            profile: intern,
          ),
        ),
      );

      return;
    }

    await supabase.auth.signOut();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
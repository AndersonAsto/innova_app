import 'package:flutter/material.dart';
import 'package:innova/environments/authService.dart';
import 'package:innova/login/animation.dart';
import 'package:innova/login/authGate.dart';
import 'package:innova/main.dart';
import 'package:innova/navigation/internNavigationScreen.dart';
import 'package:innova/navigation/managerNavigationScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../environments/environments.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService(supabase).login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      SessionService.profile = result['profile'];
      if (!mounted) return;

      if (result['type'] == 'manager') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ManagerNavigationScreen(profile: result['profile'])),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => InternNavigationScreen(profile: result['profile'])),
        );
      }
    } on AuthException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo o contraseña incorrectos')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final cardWidth = sw < 500 ? sw * 0.9 : (sw < 900 ? sw * 0.5 : 420.0);

    return Scaffold(
      backgroundColor: appColors[0],
      body: Stack(
        children: [
          // ── Fondo animado (sin cambios) ──────────────────────────────
          const AnimatedBackground(),

          // ── Contenido centrado con scroll por si la pantalla es chica ─
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: SizedBox(
                width: cardWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo ───────────────────────────────────────────
                    Image.asset(
                      'assets/logo.webp',
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),

                    // ── Card de login ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Título
                          const Text(
                            'Bienvenido',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Inicia sesión para continuar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Campo correo ───────────────────────────
                          _inputField(
                            controller: _emailController,
                            label: 'Correo institucional',
                            icon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 14),

                          // ── Campo contraseña ───────────────────────
                          _inputField(
                            controller: _passwordController,
                            label: 'Contraseña',
                            icon: Icons.lock_outline_rounded,
                            obscure: !_isPasswordVisible,
                            suffix: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 20,
                              ),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Botón ingresar ─────────────────────────
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1178D5),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFF1178D5).withValues(alpha: 0.5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Iniciar Sesión',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // ── Link solicitar cuenta ──────────────────────────
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        '¿No tienes cuenta? Solicitar acceso',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
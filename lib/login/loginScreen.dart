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
  TextEditingController institutionalEmailInternController = TextEditingController();
  TextEditingController passwordInternController = TextEditingController();
  TextEditingController institutionalEmailManagerController = TextEditingController();
  TextEditingController passwordManagerController = TextEditingController();
  bool _isPasswordVisible = false;
  bool isManager = true;

  TextEditingController get emailController => isManager ? institutionalEmailManagerController : institutionalEmailInternController;
  TextEditingController get passwordController => isManager ? passwordManagerController : passwordInternController;

  @override
  void dispose() {
    institutionalEmailInternController.dispose();
    passwordInternController.dispose();
    institutionalEmailManagerController.dispose();
    passwordManagerController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    try {

      final result = await AuthService(
        supabase,
      ).login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      SessionService.profile = result['profile'];
      if (!mounted) return;

      if (result['type'] == 'manager') {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ManagerNavigationScreen(
              profile: result['profile'],
            ),
          ),
        );

      } else {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InternNavigationScreen(
              profile: result['profile'],
            ),
          ),
        );

      }

    } on AuthException catch (_) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Correo o contraseña incorrectos',
          ),
        ),
      );

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );

    }
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: appColors[0],
      body: Stack(
        children: [
          const AnimatedBackground(),
          RepaintBoundary(
            child: Center(
              child: SizedBox(
                width: screenWidth < 700 ? screenWidth * 0.85 : screenWidth * 0.4,
                height:  screenHeight * 0.6,
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: screenWidth < 700 ? screenWidth * 0.85 : screenWidth * 0.4,
                        height:  screenHeight < 700 ? 0 : screenHeight * 0.2,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/logo.webp'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => isManager = true),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isManager ? Colors.blue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text('Gestor', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => isManager = false),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: !isManager ? Colors.blue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text('Equipo', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20,),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                        child: TextField(
                          style: const TextStyle(fontSize: 10, color: Colors.black),
                          decoration: const InputDecoration(
                            labelText: 'Correo Institucional',
                            labelStyle: TextStyle(fontSize: 10, color: Colors.black),
                            prefixIcon: Icon(Icons.person, color: Colors.black, size: 20),
                            contentPadding: EdgeInsets.all(10),
                            border: InputBorder.none,
                          ),
                          controller: institutionalEmailInternController,
                          enabled: true,
                        ),
                      ),
                      const SizedBox(height: 20,),
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                        child: TextField(
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(fontSize: 10, color: Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            labelStyle: const TextStyle(fontSize: 10, color: Colors.black),
                            prefixIcon: const Icon(Icons.password, color: Colors.black, size: 20),
                            contentPadding: const EdgeInsets.all(10),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: Colors.black,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            border: InputBorder.none,
                          ),
                          controller: passwordInternController,
                          enabled: true,
                        ),
                      ),
                      const SizedBox(height: 20,),
                      ElevatedButton(
                        onPressed: () => login(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Iniciar Sesión', style: TextStyle(color: Colors.white),),
                      ),
                      const SizedBox(height: 20,),
                      TextButton(onPressed: (){}, child: const Text('¿No tiene una cuenta? Solicitar Cuenta', style: TextStyle( color: Colors.white),textAlign: TextAlign.center,)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      )
    );
  }
}
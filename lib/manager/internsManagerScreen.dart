import 'package:flutter/material.dart';
import 'package:innova/environments/custom.widgets.dart';
import 'package:innova/environments/environments.dart';
import 'dart:math';

String generateSecurePassword() {
  const lowercase = 'abcdefghijklmnopqrstuvwxyz';
  const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const numbers = '0123456789';
  const symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?/~';

  final rnd = Random.secure();

  // Garantizar al menos un carácter de cada tipo
  final char1 = lowercase[rnd.nextInt(lowercase.length)];
  final char2 = uppercase[rnd.nextInt(uppercase.length)];
  final char3 = numbers[rnd.nextInt(numbers.length)];
  final char4 = symbols[rnd.nextInt(symbols.length)];

  // Combinar todos los caracteres posibles para completar los 12 caracteres
  const allAvailable = lowercase + uppercase + numbers + symbols;

  // Faltan 8 caracteres para completar los 12
  String remaining = '';
  for (int i = 0; i < 8; i++) {
    remaining += allAvailable[rnd.nextInt(allAvailable.length)];
  }

  // Juntar todo y desordenar para que la posición de los caracteres obligatorios sea aleatoria
  final combined = char1 + char2 + char3 + char4 + remaining;
  final passwordList = combined.split('')..shuffle(rnd);

  return passwordList.join('');
}

class InternsManagerScreen extends StatefulWidget {
  const InternsManagerScreen({super.key});

  @override
  State<InternsManagerScreen> createState() => _InternsManagerScreenState();
}

class _InternsManagerScreenState extends State<InternsManagerScreen> {
  TextEditingController namesController = TextEditingController();
  TextEditingController fathersSurnameController = TextEditingController();
  TextEditingController mothersSurnameController = TextEditingController();
  TextEditingController dniController = TextEditingController();
  TextEditingController phoneNumberController = TextEditingController();
  TextEditingController institutionalEmailController = TextEditingController();
  TextEditingController passwordHashController = TextEditingController();
  TextEditingController roleController = TextEditingController();
  TextEditingController interShipStartDateController = TextEditingController();
  TextEditingController interShipEndDateController = TextEditingController();

  bool isIntern = true;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    print(isIntern);
  }

  Future<void> showUsersForm() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CustomAlertDialog(
              title: 'Agregar Practicante / Gestor',
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 10, color: Colors.black),
                        decoration: const InputDecoration(
                          labelText: 'Nombres',
                          labelStyle: TextStyle(fontSize: 10, color: Colors.black),
                          contentPadding: EdgeInsets.all(10),
                          border: InputBorder.none,
                        ),
                        controller: namesController,
                        enabled: true,
                      ),
                    ),
                    const SizedBox(height: 10,),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 10, color: Colors.black),
                        decoration: const InputDecoration(
                          labelText: 'Apellido Paterno',
                          labelStyle: TextStyle(fontSize: 10, color: Colors.black),
                          contentPadding: EdgeInsets.all(10),
                          border: InputBorder.none,
                        ),
                        controller: fathersSurnameController,
                        enabled: true,
                      ),
                    ),
                    const SizedBox(height: 10,),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 10, color: Colors.black),
                        decoration: const InputDecoration(
                          labelText: 'Apellido Materno',
                          labelStyle: TextStyle(fontSize: 10, color: Colors.black),
                          contentPadding: EdgeInsets.all(10),
                          border: InputBorder.none,
                        ),
                        controller: mothersSurnameController,
                        enabled: true,
                      ),
                    ),
                    const SizedBox(height: 10,),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 10, color: Colors.black),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'DNI',
                          labelStyle: TextStyle(fontSize: 10, color: Colors.black),
                          contentPadding: EdgeInsets.all(10),
                          border: InputBorder.none,
                        ),
                        controller: dniController,
                        enabled: true,
                      ),
                    ),
                    const SizedBox(height: 10,),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 10, color: Colors.black),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          labelStyle: TextStyle(fontSize: 10, color: Colors.black),
                          contentPadding: EdgeInsets.all(10),
                          border: InputBorder.none,
                        ),
                        controller: phoneNumberController,
                        enabled: true,
                      ),
                    ),
                    const SizedBox(height: 10,),
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
                          contentPadding: EdgeInsets.all(10),
                          border: InputBorder.none,
                        ),
                        controller: institutionalEmailController,
                        enabled: true,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                          prefixIcon: IconButton(
                            tooltip: 'Generar contraseña',
                            onPressed: () {
                              setStateDialog(() {
                                passwordHashController.text = generateSecurePassword();
                              });
                            },
                            icon: const Icon(Icons.password, size: 20, color: Colors.black),
                          ),
                          contentPadding: const EdgeInsets.all(10),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.black,
                              size: 20,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: InputBorder.none,
                        ),
                        controller: passwordHashController,
                        enabled: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar', style: TextStyle(fontSize: 10)),
                  onPressed: () => Navigator.pop(context),
                ),
                CustomElevatedButton(
                  label: 'Confirmar',
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appColors[0],
        automaticallyImplyLeading: false,
        title: const Text('Practicantes', style: TextStyle(color: Colors.white, fontSize: 15),),
      ),
      body: const Center(
        child: Column(
          children: [
            Text('Hola')
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showUsersForm,
        mini: true,
        backgroundColor: appColors[0],
        tooltip: 'Agregar practicante / gestor',
        hoverColor: const Color(0x52FFFFFF),
        child: const Icon(Icons.add, color: Colors.white,),
      ),
    );
  }
}
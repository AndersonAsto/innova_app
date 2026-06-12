import 'package:flutter/material.dart';
import 'package:innova/environments/custom.widgets.dart';
import 'package:innova/environments/environments.dart';
import 'dart:math';
import 'package:innova/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  bool _isPasswordVisible = false;
  bool isLoading = true;
  bool isIntern = true;
  String? selectedRole;
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
  List<String> managerRoles = [
    'Administrador',
    'Coordinador',
    'Gestor de Proyectos'
  ];
  List<Map<String, dynamic>> interns = [];
  List<Map<String, dynamic>> managers = [];
  RealtimeChannel? internsChannel;
  RealtimeChannel? managersChannel;

  @override
  void initState() {
    super.initState();
    loadData();
    subscribeRealtime();
  }

  @override
  void dispose() {
    internsChannel?.unsubscribe();
    managersChannel?.unsubscribe();
    super.dispose();
  }

  void clearForm() {
    namesController.clear();
    fathersSurnameController.clear();
    mothersSurnameController.clear();
    dniController.clear();
    phoneNumberController.clear();
    institutionalEmailController.clear();
    passwordHashController.clear();
    roleController.clear();
    interShipStartDateController.clear();
    interShipEndDateController.clear();

    selectedRole = null;
  }

  void subscribeRealtime() {
    internsChannel = supabase
        .channel('practicantes_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'practicantes',
      callback: (payload) async {
        await loadData();
      },
    )
        .subscribe();

    managersChannel = supabase
        .channel('gestores_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'administradores_gestores',
      callback: (payload) async {
        await loadData();
      },
    )
        .subscribe();
  }

  void showInternDetails(Map<String, dynamic> intern) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${intern['names']} '
                    '${intern['fathers_surname']} '
                    '${intern['mothers_surname']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              infoTile('DNI', intern['dni']),
              infoTile('Teléfono', intern['phone_number']),
              infoTile('Correo', intern['institutional_email']),
              infoTile('Inicio', intern['internship_start_date']),
              infoTile('Fin', intern['internship_end_date']),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        isIntern = intern.containsKey('internship_start_date');

                        await showUsersForm(
                            user: intern,
                            isEdit: true
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {

                        final confirm =
                        await showDialog<bool>(
                          context: context,
                          builder: (_) {
                            return AlertDialog(
                              title: const Text(
                                'Eliminar registro',
                              ),
                              content: const Text(
                                '¿Desea continuar?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(
                                        context,
                                        false,
                                      ),
                                  child: const Text(
                                    'Cancelar',
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(
                                        context,
                                        true,
                                      ),
                                  child: const Text(
                                    'Eliminar',
                                  ),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm == true) {
                          await deleteUser(intern);
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Eliminar'),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> showUsersForm({Map<String, dynamic>? user, bool isEdit = false}) async {
    if (isEdit && user != null) {
      namesController.text = user['names'] ?? '';
      fathersSurnameController.text = user['fathers_surname'] ?? '';
      mothersSurnameController.text = user['mothers_surname'] ?? '';
      dniController.text = user['dni'] ?? '';
      phoneNumberController.text = user['phone_number'] ?? '';
      institutionalEmailController.text = user['institutional_email'] ?? '';
      roleController.text = user['role'] ?? '';
      selectedRole = user['role'];
      interShipStartDateController.text = user['internship_start_date'] ?? '';
      interShipEndDateController.text = user['internship_end_date'] ?? '';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CustomAlertDialog(
              title: isEdit == false ? 'Agregar Practicante / Gestor': 'Actualizar Practicante / Gestor',
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setStateDialog(() => isIntern = true),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isIntern ? Colors.blue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Practicante', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setStateDialog(() => isIntern = false),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !isIntern ? Colors.blue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('Gestor', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10,),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 10, color: Colors
                            .black),
                        decoration: const InputDecoration(
                          labelText: 'Nombres',
                          labelStyle: TextStyle(
                              fontSize: 10, color: Colors.black),
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
                        style: const TextStyle(fontSize: 10, color: Colors
                            .black),
                        decoration: const InputDecoration(
                          labelText: 'Apellido Paterno',
                          labelStyle: TextStyle(
                              fontSize: 10, color: Colors.black),
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
                        style: const TextStyle(fontSize: 10, color: Colors
                            .black),
                        decoration: const InputDecoration(
                          labelText: 'Apellido Materno',
                          labelStyle: TextStyle(
                              fontSize: 10, color: Colors.black),
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
                        style: const TextStyle(fontSize: 10, color: Colors
                            .black),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'DNI',
                          labelStyle: TextStyle(
                              fontSize: 10, color: Colors.black),
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
                        style: const TextStyle(fontSize: 10, color: Colors
                            .black),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          labelStyle: TextStyle(
                              fontSize: 10, color: Colors.black),
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
                        style: const TextStyle(fontSize: 10, color: Colors
                            .black),
                        decoration: const InputDecoration(
                          labelText: 'Correo Institucional',
                          labelStyle: TextStyle(
                              fontSize: 10, color: Colors.black),
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
                        style: const TextStyle(fontSize: 10, color: Colors
                            .black),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: const TextStyle(
                              fontSize: 10, color: Colors.black),
                          prefixIcon: IconButton(
                            tooltip: 'Generar contraseña',
                            onPressed: () {
                              setStateDialog(() {
                                passwordHashController.text =
                                    generateSecurePassword();
                              });
                            },
                            icon: const Icon(
                                Icons.password, size: 20, color: Colors.black),
                          ),
                          contentPadding: const EdgeInsets.all(10),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons
                                  .visibility_off,
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
                    if (isIntern == true)...[
                      const SizedBox(height: 10),
                      timeSelector()
                    ],
                    if (isIntern == false)...[
                      const SizedBox(height: 10),
                      managerRolesDrop()
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar', style: TextStyle(fontSize: 10)),
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                ),
                CustomElevatedButton(
                  label: 'Confirmar',
                  onPressed: () async{
                    if (isEdit) {
                      await updateUser(user!);
                    } else {
                      await registerUser();
                    }
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> registerUser() async {
    try {

      final response = await supabase.functions.invoke(
        'rapid-task',
        body: {
          'type': isIntern ? 'intern' : 'manager',

          'email': institutionalEmailController.text.trim(),
          'password': passwordHashController.text.trim(),

          'names': namesController.text.trim(),
          'fathers_surname': fathersSurnameController.text.trim(),
          'mothers_surname': mothersSurnameController.text.trim(),
          'dni': dniController.text.trim(),
          'phone_number': phoneNumberController.text.trim(),

          'internship_start_date':
          interShipStartDateController.text.trim(),
          'internship_end_date':
          interShipEndDateController.text.trim(),

          'role': roleController.text.trim(),
        },
      );

      print(response.data);

      if (response.data['success'] == true) {

        clearForm();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario creado correctamente'),
          ),
        );
      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
      print(e.toString());
    }
  }

  Future<void> loadData() async {
    try {

      final internsResponse =
      await supabase
          .from('practicantes')
          .select()
          .order('id');

      final managersResponse =
      await supabase
          .from('administradores_gestores')
          .select()
          .order('id');

      setState(() {
        interns = List<Map<String, dynamic>>.from(internsResponse);
        managers = List<Map<String, dynamic>>.from(managersResponse);
        isLoading = false;
      });

    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> loadInterns() async {
    try {
      final response = await supabase
          .from('practicantes')
          .select()
          .order('id');

      setState(() {
        interns = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint(e.toString());

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateUser(Map<String, dynamic> user,) async {
    try {
      if (user.containsKey('internship_start_date')) {
        await supabase.from('practicantes').update({
          'names': namesController.text.trim(),
          'fathers_surname': fathersSurnameController.text.trim(),
          'mothers_surname': mothersSurnameController.text.trim(),
          'dni': dniController.text.trim(),
          'phone_number': phoneNumberController.text.trim(),
          'institutional_email': institutionalEmailController.text.trim(),
          'internship_start_date': interShipStartDateController.text.trim(),
          'internship_end_date': interShipEndDateController.text.trim(),
        }).eq('id', user['id']);
      } else {
        await supabase.from('administradores_gestores').update({
          'names': namesController.text.trim(),
          'fathers_surname': fathersSurnameController.text.trim(),
          'mothers_surname': mothersSurnameController.text.trim(),
          'dni': dniController.text.trim(),
          'phone_number': phoneNumberController.text.trim(),
          'institutional_email': institutionalEmailController.text.trim(),
          'role': roleController.text.trim(),
        }).eq('id', user['id']);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    try {
      if (user.containsKey('internship_start_date')) {
        await supabase
            .from('practicantes')
            .delete()
            .eq('id', user['id']);
      } else {
        await supabase
            .from('administradores_gestores')
            .delete()
            .eq('id', user['id']);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appColors[0],
        automaticallyImplyLeading: false,
        title: const Text('Practicantes', style: TextStyle(color: Colors.white, fontSize: 15),),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : ListView(
        padding: const EdgeInsets.all(15),
        children: [
          sectionTitle('Gestores', Icons.admin_panel_settings,),
          const SizedBox(height: 20),
          ...managers.map(buildManagerCard),
          const SizedBox(height: 20),
          sectionTitle('Practicantes', Icons.school,),
          const SizedBox(height: 20),
          ...interns.map(buildInternCard),
        ],
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

  Widget managerRolesDrop() {
    return CustomDropdownButtonFormField<String>(
      label: 'Rol',
      value: selectedRole,
      items: managerRoles,
      itemValue: (role) => role,
      itemAsString: (role) => role,
      onChanged: (value) {
        setState(() {
          selectedRole = value as String?;
          roleController.text = value ?? '';
        });
      },
      validator: (value) => value == null ? 'Seleccione un rol' : null,
    );
  }

  Widget timeSelector() {
    DateTime? startDate;
    final now = DateTime.now();
    final currentYear = now.year;
    final nextYear = currentYear + 1;

    return Column(
      children: [
        CustomTextField(
          controller: interShipStartDateController,
          label: 'Inicio de Prácticas',
          isDate: true,
          firstDate: DateTime(currentYear, 1, 1),
          lastDate: DateTime(currentYear, 12, 31),
        ),
        const SizedBox(height: 10),
        CustomTextField(
          controller: interShipEndDateController,
          label: 'Fin de Prácticas',
          isDate: true,
          firstDate: startDate ?? DateTime(currentYear, 1, 1),
          lastDate: DateTime(nextYear, 12, 31),
        ),
      ],
    );
  }

  Widget infoTile(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(value?.toString() ?? ''),
        ],
      ),
    );
  }

  Widget sectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: appColors[0],
        borderRadius: BorderRadius.circular(10)
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.white
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInternCard(Map<String, dynamic> intern) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green,
          child: Text(
            intern['names'][0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          '${intern['names']} ${intern['fathers_surname']}',
        ),
        subtitle: const Text('Practicante'),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15, color: Colors.black,
        ),
        onTap: () {
          showInternDetails(intern);
        },
      ),
    );
  }

  Widget buildManagerCard(Map<String, dynamic> manager) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: getRoleColor(manager['role']),
          child: Text(
            manager['names'][0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          '${manager['names']} ${manager['fathers_surname']}',
        ),
        subtitle: Text(
          manager['role'] ?? '',
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15,
        ),
        onTap: () {
          showInternDetails(manager);
        },
      ),
    );
  }

  Color getRoleColor(String role) {
    switch(role) {
      case 'Administrador': return Colors.red;
      case 'Coordinador': return Colors.orange;
      default: return Colors.blue;
    }
  }
}

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

  // ─── Paleta (misma que el resto de la app) ────────────────────────────────
  static const Color _primary = Color(0xFF1A3A6B);
  static const Color _accent  = Color(0xFF2EC4B6);
  static const Color _bgLight = Color(0xFFF4F6FA);

  String generateSecurePassword() {
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?/~';

    final rnd = Random.secure();

    final char1 = lowercase[rnd.nextInt(lowercase.length)];
    final char2 = uppercase[rnd.nextInt(uppercase.length)];
    final char3 = numbers[rnd.nextInt(numbers.length)];
    final char4 = symbols[rnd.nextInt(symbols.length)];

    const allAvailable = lowercase + uppercase + numbers + symbols;

    String remaining = '';
    for (int i = 0; i < 8; i++) {
      remaining += allAvailable[rnd.nextInt(allAvailable.length)];
    }

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

  // ─── Helpers visuales ──────────────────────────────────────────────────────
  String initials(Map<String, dynamic> user) {
    final name   = (user['names'] ?? '').toString();
    final father = (user['fathers_surname'] ?? '').toString();
    return '${name.isNotEmpty ? name[0] : ''}${father.isNotEmpty ? father[0] : ''}';
  }

  bool _isIntern(Map<String, dynamic> user) => user.containsKey('internship_start_date');

  Color _roleColor(Map<String, dynamic> user) {
    if (_isIntern(user)) return _accent;
    return getRoleColor(user['role'] ?? '');
  }

  IconData _roleIcon(Map<String, dynamic> user) {
    if (_isIntern(user)) return Icons.school_rounded;
    switch (user['role']) {
      case 'Administrador': return Icons.shield_rounded;
      case 'Coordinador':   return Icons.supervisor_account_rounded;
      default:              return Icons.admin_panel_settings_rounded;
    }
  }

  // ─── Detalle del usuario (perfil) ─────────────────────────────────────────
  void showInternDetails(Map<String, dynamic> user) {
    final color = _roleColor(user);
    final role  = _isIntern(user) ? 'Practicante' : (user['role'] ?? 'Gestor');
    final ini   = initials(user);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Avatar grande con gradiente ─────────────────────────
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.65)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: Text(ini, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${user['names']} ${user['fathers_surname']} ${user['mothers_surname']}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
              ),
              const SizedBox(height: 6),
              // ── Badge de rol ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_roleIcon(user), size: 15, color: color),
                    const SizedBox(width: 5),
                    Text(role, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Tarjetas de info ─────────────────────────────────────
              ...[
                (Icons.badge_rounded,         'DNI',      user['dni']),
                (Icons.phone_rounded,          'Teléfono', user['phone_number']),
                (Icons.email_rounded,          'Correo',   user['institutional_email']),
                if (_isIntern(user))
                  (Icons.calendar_today_rounded, 'Inicio', user['internship_start_date']),
                if (_isIntern(user))
                  (Icons.event_rounded,          'Fin',    user['internship_end_date']),
              ].map((item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(item.$1, size: 18, color: _accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$2, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                          Text(item.$3?.toString() ?? '—',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              )),

              const SizedBox(height: 10),
              // ── Acciones ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.edit_rounded,
                      label: 'Editar',
                      color: _accent,
                      onTap: () async {
                        Navigator.pop(context);
                        isIntern = _isIntern(user);
                        await showUsersForm(user: user, isEdit: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.delete_rounded,
                      label: 'Eliminar',
                      color: Colors.redAccent,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            title: const Text('Eliminar Registro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            content: const Text('¿Desea continuar? Esta acción no se puede deshacer.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await deleteUser(user);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        onPressed: onTap,
      ),
    );
  }

  // ─── Formulario crear/editar ──────────────────────────────────────────────
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
              title: isEdit == false ? 'Agregar Practicante / Gestor' : 'Actualizar Practicante / Gestor',
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Selector tipo de usuario ─────────────────────
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setStateDialog(() => isIntern = true),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isIntern ? _accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('Practicante',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: isIntern ? FontWeight.bold : FontWeight.normal)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setStateDialog(() => isIntern = false),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !isIntern ? _accent : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('Gestor',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: !isIntern ? FontWeight.bold : FontWeight.normal)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _styledField('Nombres', namesController, Icons.badge_outlined),
                    const SizedBox(height: 10),
                    _styledField('Apellido Paterno', fathersSurnameController, Icons.person_outline_rounded),
                    const SizedBox(height: 10),
                    _styledField('Apellido Materno', mothersSurnameController, Icons.person_outline_rounded),
                    const SizedBox(height: 10),
                    _styledField('DNI', dniController, Icons.badge_rounded, keyboardType: TextInputType.number),
                    const SizedBox(height: 10),
                    _styledField('Teléfono', phoneNumberController, Icons.phone_rounded, keyboardType: TextInputType.number),
                    const SizedBox(height: 10),
                    _styledField('Correo Institucional', institutionalEmailController, Icons.email_rounded),
                    const SizedBox(height: 10),
                    // ── Contraseña con generador ──────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        obscureText: !_isPasswordVisible,
                        style: const TextStyle(fontSize: 12, color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                          prefixIcon: IconButton(
                            tooltip: 'Generar contraseña',
                            onPressed: () {
                              setStateDialog(() {
                                passwordHashController.text = generateSecurePassword();
                              });
                            },
                            icon: const Icon(Icons.password_rounded, size: 18, color: _accent),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              color: Colors.grey,
                              size: 18,
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
                    if (isIntern == true) ...[
                      const SizedBox(height: 10),
                      timeSelector(),
                    ],
                    if (isIntern == false) ...[
                      const SizedBox(height: 10),
                      managerRolesDrop(),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  onPressed: () async {
                    Navigator.pop(context);
                  },
                ),
                CustomElevatedButton(
                  label: 'Confirmar',
                  onPressed: () async {
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

  Widget _styledField(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 12, color: Colors.black),
        decoration: InputDecoration(
          icon: Icon(icon, size: 17, color: _accent),
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ─── Registro / actualización / eliminación (sin cambios de lógica) ──────
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

          'internship_start_date': interShipStartDateController.text.trim(),
          'internship_end_date': interShipEndDateController.text.trim(),

          'role': roleController.text.trim(),
        },
      );

      if (response.data['success'] == true) {
        clearForm();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado correctamente')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      debugPrint(e.toString());
    }
  }

  Future<void> loadData() async {
    try {
      final internsResponse = await supabase.from('practicantes').select().order('id');
      final managersResponse = await supabase.from('administradores_gestores').select().order('id');

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
      final response = await supabase.from('practicantes').select().order('id');

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

  Future<void> updateUser(Map<String, dynamic> user) async {
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
        await supabase.from('practicantes').delete().eq('id', user['id']);
      } else {
        await supabase.from('administradores_gestores').delete().eq('id', user['id']);
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // ─── Pantalla principal ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: screenWidth > 700 ? AppBar(
        backgroundColor: appColors[0],
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text('Prácticantes', style: TextStyle(color: Colors.white, fontSize: 15),),
            const SizedBox(width: 10,),
            Text('(${managers.length} gestores · ${interns.length} practicantes)', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
          ],
        ),
      ) : null,
      body: CustomScrollView(
        slivers: [
          // ── Contenido ────────────────────────────────────────────────
          if (isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  sectionTitle('Gestores', Icons.admin_panel_settings_rounded, managers.length),
                  const SizedBox(height: 12),
                  if (managers.isEmpty)
                    _emptySection('Sin gestores registrados')
                  else
                    ...managers.map(buildUserCard),
                  const SizedBox(height: 24),
                  sectionTitle('Practicantes', Icons.school_rounded, interns.length),
                  const SizedBox(height: 12),
                  if (interns.isEmpty)
                    _emptySection('Sin practicantes registrados')
                  else
                    ...interns.map(buildUserCard),
                ]),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showUsersForm,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── Sección con contador ──────────────────────────────────────────────────
  Widget sectionTitle(String title, IconData icon, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFF2A4F8C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _emptySection(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
    );
  }

  // ─── Card de usuario (gestor o practicante) ───────────────────────────────
  Widget buildUserCard(Map<String, dynamic> user) {
    final color   = _roleColor(user);
    final role    = _isIntern(user) ? 'Practicante' : (user['role'] ?? 'Gestor');
    final ini     = initials(user);

    return GestureDetector(
      onTap: () => showInternDetails(user),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            children: [
              // Avatar con gradiente
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Center(
                  child: Text(ini, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 14),
              // Nombre + badge de rol
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user['names']} ${user['fathers_surname']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade300),
            ],
          ),
        ),
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

  Color getRoleColor(String role) {
    switch (role) {
      case 'Administrador': return Colors.redAccent;
      case 'Coordinador':   return Colors.orange;
      default:              return _primary; // Gestor de Proyectos
    }
  }
}
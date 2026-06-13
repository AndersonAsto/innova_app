import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:innova/environments/custom.widgets.dart';
import 'package:innova/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectsManagerScreen extends StatefulWidget {
  const ProjectsManagerScreen({super.key});

  @override
  State<ProjectsManagerScreen> createState() => _ProjectsManagerScreenState();
}

class _ProjectsManagerScreenState extends State<ProjectsManagerScreen> {
  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController imageUrlController = TextEditingController();

  bool projectStatus = true;
  List<Map<String, dynamic>> projects = [];
  RealtimeChannel? projectsChannel;
  bool isLoading = true;
  RealtimeChannel? participantsChannel;
  List<Map<String, dynamic>> projectParticipants = [];
  List<Map<String, dynamic>> interns = [];
  int? selectedLeaderId;
  List<int> selectedMembersIds = [];

  // ─── Paleta de colores centralizada ───────────────────────────────────────
  static const Color _primary = Color(0xFF1A3A6B);
  static const Color _accent = Color(0xFF2EC4B6);
  static const Color _leaderColor = Color(0xFF1A3A6B);
  static const Color _memberColor = Color(0xFF2EC4B6);
  static const Color _bgLight = Color(0xFFF4F6FA);
  static const Color _cardBg = Colors.white;

  Widget projectImage(String? url) {
    if (url == null || url.trim().isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    loadProjects();
    subscribeRealTime();
  }

  @override
  void dispose() {
    projectsChannel?.unsubscribe();
    participantsChannel?.unsubscribe();
    titleController.dispose();
    descriptionController.dispose();
    imageUrlController.dispose();
    super.dispose();
  }

  void subscribeRealTime() {
    projectsChannel = supabase.channel('projects_changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'proyecto',
      callback: (_) async => await loadProjects(),
    ).subscribe();

    participantsChannel = supabase.channel('participants_changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'proyecto_participantes',
      callback: (_) async => await loadProjects(),
    ).subscribe();
  }

  Future<void> loadParticipants(int projectId) async {
    final response = await supabase
        .from('proyecto_participantes')
        .select('''*, practicantes(id, names, fathers_surname, mothers_surname)''')
        .eq('proyecto_id', projectId);
    projectParticipants = List<Map<String, dynamic>>.from(response);
  }

  Future<void> loadInterns() async {
    final response = await supabase.from('practicantes').select().order('names');
    interns = List<Map<String, dynamic>>.from(response);
  }

  Map<String, dynamic>? getLeader() {
    try {
      return projectParticipants.firstWhere((e) => e['role'] == 'Líder');
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> getMembers() =>
      projectParticipants.where((e) => e['role'] == 'Integrante').toList();

  Future<List<Map<String, dynamic>>> getProjectParticipants(int projectId) async {
    final response = await supabase.from('proyecto_participantes').select('''
        *, practicantes(id, names, fathers_surname, mothers_surname, dni, phone_number,
          institutional_email, internship_start_date, internship_end_date)
      ''').eq('proyecto_id', projectId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createProject() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final imageUrl = imageUrlController.text.trim();

    if (title.isEmpty) throw Exception('El título del proyecto es obligatorio');

    final project = await supabase
        .from('proyecto')
        .insert({'title': title, 'description': description, 'img_url': imageUrl, 'status': projectStatus})
        .select()
        .single();

    final projectId = project['id'];
    try {
      await supabase.from('kanban_columnas').insert([
        {'proyecto_id': projectId, 'name': 'Pendiente', 'position': 1, 'parent_column_id': null, 'is_default': true, 'status': true},
        {'proyecto_id': projectId, 'name': 'En Proceso', 'position': 2, 'parent_column_id': null, 'is_default': true, 'status': true},
        {'proyecto_id': projectId, 'name': 'Terminado', 'position': 3, 'parent_column_id': null, 'is_default': true, 'status': true},
      ]);
    } catch (e) {
      await supabase.from('proyecto').delete().eq('id', projectId);
      throw Exception('No se pudieron crear las columnas Kanban del proyecto');
    }
    clearProjectForm();
  }

  void clearProjectForm() {
    titleController.clear();
    descriptionController.clear();
    imageUrlController.clear();
    projectStatus = true;
  }

  Future<void> updateProject(int projectId) async {
    await supabase.from('proyecto').update({
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'img_url': imageUrlController.text.trim(),
      'status': projectStatus,
    }).eq('id', projectId);
  }

  String initials(Map<String, dynamic> intern) {
    final name = intern['names'] ?? '';
    final father = intern['fathers_surname'] ?? '';
    return '${name.isNotEmpty ? name[0] : ''}${father.isNotEmpty ? father[0] : ''}';
  }

  // ─── Avatar de participante mejorado ──────────────────────────────────────
  Widget participantAvatar({
    required Map<String, dynamic> intern,
    required Color color,
    required String role,
    double size = 36,
  }) {
    return GestureDetector(
      onTap: () => showInternDetails(intern, role),
      child: Tooltip(
        message: '${intern['names']} ${intern['fathers_surname']}',
        child: Container(
          width: size,
          height: size,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Center(
            child: Text(
              initials(intern),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.33,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showParticipantsManager(Map<String, dynamic> project) async {
    await loadInterns();
    await loadParticipants(project['id']);
    selectedMembersIds.clear();
    selectedLeaderId = null;

    for (final participant in projectParticipants) {
      final internId = participant['practicante_id'];
      selectedMembersIds.add(internId);
      if (participant['role'] == 'Líder') selectedLeaderId = internId;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _bgLight,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    const Text('Participantes del Proyecto',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primary)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: interns.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (_, index) {
                            final intern = interns[index];
                            final internId = intern['id'];
                            final isSelected = selectedMembersIds.contains(internId);
                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: _accent,
                              title: Text(
                                '${intern['names']} ${intern['fathers_surname']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == true) {
                                    selectedMembersIds.add(internId);
                                  } else {
                                    selectedMembersIds.remove(internId);
                                    if (selectedLeaderId == internId) selectedLeaderId = null;
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedLeaderId,
                        style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.black87, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Líder del proyecto',
                          labelStyle: TextStyle(color: _primary),
                          border: InputBorder.none,
                        ),
                        items: selectedMembersIds.map((id) {
                          final intern = interns.firstWhere((e) => e['id'] == id);
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text('${intern['names']} ${intern['fathers_surname']}'),
                          );
                        }).toList(),
                        onChanged: (value) => setModalState(() => selectedLeaderId = value),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Guardar Participantes', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await saveParticipants(project['id']);
                            nav.pop();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Participantes actualizados.')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text(e.toString())));
                            if (kDebugMode) print(e.toString());
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> deleteProject(int projectId) async {
    await supabase.from('proyecto').delete().eq('id', projectId);
  }

  // ─── Detalle del participante — estilo perfil ──────────────────────────────
  void showInternDetails(Map<String, dynamic> intern, String role) {
    final isLeader = role == 'Líder';
    final avatarColor = isLeader ? _leaderColor : _memberColor;
    final ini = initials(intern);

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
              // ── Avatar grande ──────────────────────────────────────────
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [avatarColor, avatarColor.withValues(alpha: 0.65)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: avatarColor.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: Text(ini, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${intern['names']} ${intern['fathers_surname']} ${intern['mothers_surname']}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primary),
              ),
              const SizedBox(height: 6),
              // ── Badge de rol ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isLeader ? Icons.star_rounded : Icons.person_rounded, size: 15, color: avatarColor),
                    const SizedBox(width: 5),
                    Text(role, style: TextStyle(color: avatarColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── Tarjetas de info ───────────────────────────────────────
              _infoGrid([
                _InfoItem(Icons.badge_rounded, 'DNI', intern['dni']),
                _InfoItem(Icons.phone_rounded, 'Teléfono', intern['phone_number']),
                _InfoItem(Icons.email_rounded, 'Correo', intern['institutional_email']),
                _InfoItem(Icons.calendar_today_rounded, 'Inicio', intern['internship_start_date']),
                _InfoItem(Icons.event_rounded, 'Fin', intern['internship_end_date']),
                _InfoItem(Icons.work_rounded, 'Rol', role),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _infoGrid(List<_InfoItem> items) {
    return Column(
      children: items.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _bgLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: _accent),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                Text(item.value?.toString() ?? '—', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Future<void> loadProjects() async {
    final response = await supabase.from('proyecto').select().order('created_at', ascending: false);
    setState(() {
      projects = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> showUsersForm({Map<String, dynamic>? project, bool isEdit = false}) async {
    if (isEdit && project != null) {
      titleController.text = project['title'] ?? '';
      imageUrlController.text = project['img_url'] ?? '';
      descriptionController.text = project['description'] ?? '';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CustomAlertDialog(
              title: isEdit ? 'Actualizar Proyecto' : 'Crear Proyecto',
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _styledField('Título', titleController, Icons.title_rounded),
                    const SizedBox(height: 12),
                    _styledField('URL de imagen', imageUrlController, Icons.image_rounded),
                    const SizedBox(height: 12),
                    _styledField('Descripción', descriptionController, Icons.description_rounded, maxLines: 3),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  onPressed: () => Navigator.pop(context),
                ),
                CustomElevatedButton(
                  label: 'Confirmar',
                  onPressed: () async {
                    try {
                      if (isEdit) {
                        await updateProject(project?['id']);
                      } else {
                        await createProject();
                      }
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isEdit
                            ? 'Proyecto actualizado correctamente'
                            : 'Proyecto creado con columnas Kanban'),
                      ));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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

  Widget _styledField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          icon: Icon(icon, size: 18, color: _accent),
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          border: InputBorder.none,
        ),
      ),
    );
  }

  // ─── Pantalla principal ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final activeCount = projects.where((p) => p['status'] == true).length;

    return Scaffold(
      backgroundColor: _bgLight,
      body: CustomScrollView(
        slivers: [
          // ── AppBar con stats ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: _primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D2B5E), Color(0xFF1A3A6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Proyectos',
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          Text('${projects.length} proyectos · $activeCount activos',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Lista ────────────────────────────────────────────────────
          if (isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (projects.isEmpty)
            SliverFillRemaining(child: _emptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => buildProjectsCard(projects[i]),
                  childCount: projects.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showUsersForm,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Aún no hay proyectos', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  // ─── Card estilo Netflix + dashboard ──────────────────────────────────────
  Widget buildProjectsCard(Map<String, dynamic> project) {
    final isActive = project['status'] == true;
    final hasImage = (project['img_url'] ?? '').toString().trim().isNotEmpty;

    return GestureDetector(
      onTap: () => showProjectDetails(project),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Imagen con gradiente encima ─────────────────────
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 160,
                      child: hasImage
                          ? Image.network(
                              project['img_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                    // Gradiente oscuro abajo para legibilidad
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Badge estado arriba izquierda
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? _accent : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isActive ? 'Activo' : 'Inactivo',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Título encima del gradiente abajo
                    Positioned(
                      bottom: 12, left: 14, right: 14,
                      child: Text(
                        project['title'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ),
                    // Flecha arriba derecha
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),

                // ── Sección inferior ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Descripción
                      Text(
                        project['description'] ?? 'Sin descripción',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                      ),
                      const SizedBox(height: 12),

                      // ── Barra de progreso de tareas ────────────────
                      FutureBuilder<Map<String, int>>(
                        future: _getTaskStats(project['id']),
                        builder: (context, snap) {
                          final total    = snap.data?['total'] ?? 0;
                          final done     = snap.data?['done'] ?? 0;
                          final progress = total == 0 ? 0.0 : done / total;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.task_alt_rounded, size: 13, color: _accent),
                                  const SizedBox(width: 5),
                                  Text(
                                    total == 0 ? 'Sin tareas aún' : '$done/$total tareas completadas',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _accent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 5,
                                  backgroundColor: Colors.grey.shade100,
                                  valueColor: AlwaysStoppedAnimation<Color>(_accent),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // ── Avatares del equipo ────────────────────────
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: getProjectParticipants(project['id']),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                          final participants = snapshot.data!;
                          final leader  = participants.where((e) => e['role'] == 'Líder');
                          final members = participants.where((e) => e['role'] == 'Integrante');
                          return Row(
                            children: [
                              ...leader.map((p) => participantAvatar(intern: p['practicantes'], color: _leaderColor, role: 'Líder', size: 30)),
                              ...members.map((p) => participantAvatar(intern: p['practicantes'], color: _memberColor, role: 'Integrante', size: 30)),
                              const Spacer(),
                              Text(
                                '${participants.length} miembro${participants.length != 1 ? 's' : ''}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: _primary.withValues(alpha: 0.08),
      child: Center(
        child: Icon(Icons.folder_special_rounded, size: 48, color: _primary.withValues(alpha: 0.25)),
      ),
    );
  }

  Future<Map<String, int>> _getTaskStats(int projectId) async {
    final response = await supabase
        .from('tareas')
        .select('column_id, kanban_columnas(name)')
        .eq('proyecto_id', projectId)
        .eq('status', true);
    final tasks = List<Map<String, dynamic>>.from(response);
    final total = tasks.length;
    final done  = tasks.where((t) {
      final col = t['kanban_columnas'];
      return col != null && col['name'].toString().toLowerCase() == 'terminado';
    }).length;
    return {'total': total, 'done': done};
  }

  // ─── Detalle del proyecto rediseñado ──────────────────────────────────────
  void showProjectDetails(Map<String, dynamic> project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Imagen destacada ─────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: projectImage(project['img_url']),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ── Badge de estado ──────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: project['status'] == true ? _accent.withValues(alpha: 0.12) : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            project['status'] == true ? 'Activo' : 'Inactivo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: project['status'] == true ? _accent : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(project['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primary)),
                    const SizedBox(height: 8),
                    Text(
                      project['description'] ?? 'Sin descripción',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    // ── Participantes ────────────────────────────────
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: getProjectParticipants(project['id']),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                        final participants = snapshot.data!;
                        final leader = participants.where((e) => e['role'] == 'Líder').toList();
                        final members = participants.where((e) => e['role'] == 'Integrante').toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Equipo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ...leader.map((p) => participantAvatar(intern: p['practicantes'], color: _leaderColor, role: 'Líder', size: 40)),
                                ...members.map((p) => participantAvatar(intern: p['practicantes'], color: _memberColor, role: 'Integrante', size: 40)),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // ── Botones de acción ────────────────────────────
                    _actionButton(
                      icon: Icons.group_add_rounded,
                      label: 'Agregar Integrantes',
                      color: _primary,
                      onTap: () async {
                        Navigator.pop(context);
                        await showParticipantsManager(project);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            icon: Icons.edit_rounded,
                            label: 'Editar',
                            color: _accent,
                            onTap: () async {
                              Navigator.pop(context);
                              await showUsersForm(project: project, isEdit: true);
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
                                  title: const Text('Eliminar Proyecto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  content: const Text('Esta acción no se puede deshacer. ¿Desea continuar?'),
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
                                await deleteProject(project['id']);
                                if (mounted) Navigator.pop(context);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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

  Widget infoTile(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value?.toString() ?? '', maxLines: 5),
        ],
      ),
    );
  }

  Future<void> saveParticipants(int projectId) async {
    if (selectedLeaderId == null) throw Exception('Debe seleccionar un líder');
    await supabase.from('proyecto_participantes').delete().eq('proyecto_id', projectId);
    await supabase.from('proyecto_participantes').insert({
      'proyecto_id': projectId,
      'practicante_id': selectedLeaderId,
      'role': 'Líder',
    });
    for (final memberId in selectedMembersIds) {
      if (memberId == selectedLeaderId) continue;
      await supabase.from('proyecto_participantes').insert({
        'proyecto_id': projectId,
        'practicante_id': memberId,
        'role': 'Integrante',
      });
    }
  }

  Future<void> removeParticipant(int participantId) async {
    await supabase.from('proyecto_participantes').delete().eq('id', participantId);
  }
}

// ─── Helper para items de información ─────────────────────────────────────────
class _InfoItem {
  final IconData icon;
  final String label;
  final dynamic value;
  const _InfoItem(this.icon, this.label, this.value);
}
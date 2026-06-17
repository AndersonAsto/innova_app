import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';
import 'package:innova/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CollaboratorsInternScreen extends StatefulWidget {
  const CollaboratorsInternScreen({super.key});

  @override
  State<CollaboratorsInternScreen> createState() => _CollaboratorsInternScreenState();
}

class _CollaboratorsInternScreenState extends State<CollaboratorsInternScreen> {
  // ─── Paleta (misma que el resto de la app) ────────────────────────────────
  static const Color _primary     = Color(0xFF1A3A6B);
  static const Color _accent      = Color(0xFF2EC4B6);
  static const Color _leaderColor = Color(0xFF1A3A6B);
  static const Color _memberColor = Color(0xFF2EC4B6);
  static const Color _bgLight     = Color(0xFFF4F6FA);

  List<Map<String, dynamic>> projects = [];
  Map<int, List<Map<String, dynamic>>> participantsByProject = {};
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Carga de datos ────────────────────────────────────────────────────────
  Future<void> loadData() async {
    final projectsRes = await supabase
        .from('proyecto')
        .select()
        .order('created_at', ascending: false);

    final projectsList = List<Map<String, dynamic>>.from(projectsRes);

    final Map<int, List<Map<String, dynamic>>> map = {};
    for (final project in projectsList) {
      map[project['id']] = await getProjectParticipants(project['id']);
    }

    if (!mounted) return;
    setState(() {
      projects = projectsList;
      participantsByProject = map;
      isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> getProjectParticipants(int projectId) async {
    final response = await supabase
        .from('proyecto_participantes')
        .select('''*, practicantes(id, names, fathers_surname, mothers_surname,
          dni, phone_number, institutional_email,
          internship_start_date, internship_end_date)''')
        .eq('proyecto_id', projectId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, int>> _getTaskStats(int projectId) async {
    final response = await supabase
        .from('tareas')
        .select('column_id, kanban_columnas(name)')
        .eq('proyecto_id', projectId)
        .eq('status', true);
    final tasks = List<Map<String, dynamic>>.from(response);
    final total = tasks.length;
    final done = tasks.where((t) {
      final col = t['kanban_columnas'];
      return col != null && col['name'].toString().toLowerCase() == 'terminado';
    }).length;
    return {'total': total, 'done': done};
  }

  // ─── Búsqueda ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filteredProjects {
    if (_searchQuery.isEmpty) return projects;

    return projects.where((project) {
      final title = (project['title'] ?? '').toString().toLowerCase();
      final desc  = (project['description'] ?? '').toString().toLowerCase();
      if (title.contains(_searchQuery) || desc.contains(_searchQuery)) return true;

      final participants = participantsByProject[project['id']] ?? [];
      for (final p in participants) {
        final intern = p['practicantes'];
        if (intern == null) continue;
        final fullName = '${intern['names']} ${intern['fathers_surname']} ${intern['mothers_surname']}'
            .toLowerCase();
        if (fullName.contains(_searchQuery)) return true;
      }
      return false;
    }).toList();
  }

  String initials(Map<String, dynamic> intern) {
    final name   = intern['names'] ?? '';
    final father = intern['fathers_surname'] ?? '';
    return '${name.isNotEmpty ? name[0] : ''}${father.isNotEmpty ? father[0] : ''}';
  }

  // ─── Avatar de participante ────────────────────────────────────────────────
  Widget participantAvatar({
    required Map<String, dynamic> intern,
    required Color color,
    required String role,
    double size = 30,
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
              style: TextStyle(color: Colors.white, fontSize: size * 0.33, fontWeight: FontWeight.bold),
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

  // ─── Card de proyecto (solo lectura) ──────────────────────────────────────
  Widget buildProjectCard(Map<String, dynamic> project) {
    final isActive = project['status'] == true;
    final hasImage = (project['img_url'] ?? '').toString().trim().isNotEmpty;
    final participants = participantsByProject[project['id']] ?? [];

    return GestureDetector(
      onTap: () => showProjectDetails(project, participants),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Imagen con gradiente ─────────────────────────────
                Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 150,
                      child: hasImage
                          ? Image.network(
                              project['img_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Badge estado
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
                            Container(width: 6, height: 6,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(isActive ? 'Activo' : 'Inactivo',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    // Ícono de "solo lectura"
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.visibility_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                    // Título
                    Positioned(
                      bottom: 12, left: 14, right: 14,
                      child: Text(
                        project['title'] ?? '',
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
                  ],
                ),

                // ── Sección inferior ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project['description'] ?? 'Sin descripción',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                      ),
                      const SizedBox(height: 12),

                      // Barra de progreso
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
                                  Text('${(progress * 100).toInt()}%',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _accent)),
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

                      // Avatares del equipo
                      if (participants.isEmpty)
                        Text('Sin integrantes asignados',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400))
                      else
                        Row(
                          children: [
                            ...participants.where((p) => p['role'] == 'Líder').map(
                              (p) => participantAvatar(intern: p['practicantes'], color: _leaderColor, role: 'Líder'),
                            ),
                            ...participants.where((p) => p['role'] == 'Integrante').map(
                              (p) => participantAvatar(intern: p['practicantes'], color: _memberColor, role: 'Integrante'),
                            ),
                            const Spacer(),
                            Text('${participants.length} miembro${participants.length != 1 ? 's' : ''}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          ],
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

  // ─── Detalle del proyecto (solo lectura) ──────────────────────────────────
  void showProjectDetails(Map<String, dynamic> project, List<Map<String, dynamic>> participants) {
    final leader  = participants.where((e) => e['role'] == 'Líder').toList();
    final members = participants.where((e) => e['role'] == 'Integrante').toList();
    final hasImage = (project['img_url'] ?? '').toString().trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: double.infinity,
                        height: 180,
                        child: hasImage
                            ? Image.network(
                                project['img_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imagePlaceholder(),
                              )
                            : _imagePlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 10),
                    Text(project['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primary)),
                    const SizedBox(height: 8),
                    Text(
                      project['description'] ?? 'Sin descripción',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                    ),
                    const SizedBox(height: 20),

                    if (participants.isEmpty)
                      Text('Aún no hay integrantes asignados',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade400))
                    else ...[
                      const Text('Equipo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primary)),
                      const SizedBox(height: 12),

                      if (leader.isNotEmpty) ...[
                        Text('Líder', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ...leader.map((p) => _participantRow(p['practicantes'], 'Líder', _leaderColor)),
                        const SizedBox(height: 12),
                      ],
                      if (members.isNotEmpty) ...[
                        Text('Integrantes', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ...members.map((p) => _participantRow(p['practicantes'], 'Integrante', _memberColor)),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _participantRow(Map<String, dynamic> intern, String role, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showInternDetails(intern, role),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            participantAvatar(intern: intern, color: color, role: role, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${intern['names']} ${intern['fathers_surname']}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ─── Perfil del participante ──────────────────────────────────────────────
  void showInternDetails(Map<String, dynamic> intern, String role) {
    final isLeader    = role == 'Líder';
    final avatarColor = isLeader ? _leaderColor : _memberColor;
    final ini         = initials(intern);

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
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [avatarColor, avatarColor.withValues(alpha: 0.65)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
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
              ...[
                (Icons.badge_rounded,          'DNI',      intern['dni']),
                (Icons.phone_rounded,           'Teléfono', intern['phone_number']),
                (Icons.email_rounded,           'Correo',   intern['institutional_email']),
                (Icons.calendar_today_rounded,  'Inicio',   intern['internship_start_date']),
                (Icons.event_rounded,           'Fin',      intern['internship_end_date']),
                (Icons.work_rounded,            'Rol',      role),
              ].map((item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: _bgLight, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(item.$1, size: 18, color: _accent),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                        Text(item.$3?.toString() ?? '—', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  // ─── Pantalla principal ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProjects;
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: screenWidth > 700 ? AppBar(
          backgroundColor: appColors[0],
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Text('Colaboradores', style: TextStyle(color: Colors.white, fontSize: 15),),
              const SizedBox(width: 10,),
              Text('(${projects.length} proyectos disponibles)', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
            ],
          )
      ) : null ,
      body: Column(
        children: [
          Container(
            color: _bgLight,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar proyecto o integrante...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade400,
                      size: 18,
                    ),
                    onPressed: () => _searchController.clear(),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Aún no hay proyectos'
                        : 'Sin resultados para "$_searchQuery"',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: filtered.length,
              itemBuilder: (_, i) => buildProjectCard(filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}
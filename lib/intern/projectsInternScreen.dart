import 'package:flutter/material.dart';
import 'package:innova/intern/projectKanbanScreen.dart';
import 'package:innova/login/authGate.dart';
import 'package:innova/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectsInternScreen extends StatefulWidget {
  const ProjectsInternScreen({super.key});

  @override
  State<ProjectsInternScreen> createState() => _ProjectsInternScreenState();
}

class _ProjectsInternScreenState extends State<ProjectsInternScreen> {
  List<Map<String, dynamic>> projects = [];
  bool isLoading = true;

  static const Color _primary     = Color(0xFF1A3A6B);
  static const Color _accent      = Color(0xFF2EC4B6);
  static const Color _leaderColor = Color(0xFF1A3A6B);
  static const Color _memberColor = Color(0xFF2EC4B6);
  static const Color _bgLight     = Color(0xFFF4F6FA);

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {
    final internId = SessionService.profile!['id'];
    final response = await supabase
        .from('proyecto_participantes')
        .select('role, proyecto(*)')
        .eq('practicante_id', internId);
    if (!mounted) return;
    setState(() {
      projects = List<Map<String, dynamic>>.from(response);
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
    final done  = tasks.where((t) {
      final col = t['kanban_columnas'];
      return col != null && col['name'].toString().toLowerCase() == 'terminado';
    }).length;
    return {'total': total, 'done': done};
  }

  String initials(Map<String, dynamic> intern) {
    final name   = intern['names'] ?? '';
    final father = intern['fathers_surname'] ?? '';
    return '${name.isNotEmpty ? name[0] : ''}${father.isNotEmpty ? father[0] : ''}';
  }

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

  // ─── Card estilo Netflix ──────────────────────────────────────────────────
  Widget buildProjectsCard(Map<String, dynamic> entry) {
    final project  = entry['proyecto'] as Map<String, dynamic>;
    final isActive = project['status'] == true;
    final myRole   = entry['role'] ?? '';
    final isLeader = myRole == 'Líder';
    final hasImage = (project['img_url'] ?? '').toString().trim().isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectKanbanScreen(project: project, myRole: myRole),
        ),
      ),
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
                      height: 160,
                      child: hasImage
                          ? Image.network(
                              project['img_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                    ),
                    // Gradiente oscuro
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
                            Container(width: 6, height: 6,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(isActive ? 'Activo' : 'Inactivo',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    // Badge de mi rol arriba derecha
                    Positioned(
                      top: 12, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLeader
                              ? Colors.amber.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isLeader ? Icons.star_rounded : Icons.person_rounded,
                                size: 12, color: isLeader ? Colors.white : Colors.white),
                            const SizedBox(width: 4),
                            Text(myRole,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    // Título sobre el gradiente
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
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: getProjectParticipants(project['id']),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                          final participants = snapshot.data!;
                          final leader  = participants.where((e) => e['role'] == 'Líder');
                          final members = participants.where((e) => e['role'] == 'Integrante');
                          return Row(
                            children: [
                              ...leader.map((p) => participantAvatar(intern: p['practicantes'], color: _leaderColor, role: 'Líder')),
                              ...members.map((p) => participantAvatar(intern: p['practicantes'], color: _memberColor, role: 'Integrante')),
                              const Spacer(),
                              Text('${participants.length} miembro${participants.length != 1 ? 's' : ''}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
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
    final activeCount = projects.where((p) => (p['proyecto']?['status'] ?? false) == true).length;

    return Scaffold(
      backgroundColor: _bgLight,
      body: CustomScrollView(
        slivers: [
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mis Proyectos',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('${projects.length} proyectos · $activeCount activos',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          if (isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (projects.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('No estás asignado a ningún proyecto',
                        style: TextStyle(fontSize: 15, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => buildProjectsCard(projects[i]),
                  childCount: projects.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color getRoleColor(bool role) {
    switch (role) {
      case true:  return Colors.blue;
      case false: return Colors.redAccent;
      default:    return Colors.black12;
    }
  }

  Future<List<Map<String, dynamic>>> loadColumns(int projectId) async {
    final response = await supabase
        .from('kanban_columnas').select()
        .eq('proyecto_id', projectId).eq('status', true).order('position');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> loadTasks(int projectId) async {
    final response = await supabase
        .from('tareas').select()
        .eq('proyecto_id', projectId).eq('status', true).order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }
}
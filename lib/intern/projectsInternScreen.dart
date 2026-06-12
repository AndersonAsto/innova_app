import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';
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
  List<Map<String,dynamic>> projects = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {

    final internId = SessionService.profile!['id'];

    final response = await supabase
        .from('proyecto_participantes')
        .select('''
        role,
        proyecto(
          *
        )
      ''')
        .eq('practicante_id', internId);

    projects = List<Map<String,dynamic>>.from(response);

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  bool isLeader(Map<String,dynamic> project) {
    return project['role'] == 'Líder';
  }

  Widget buildProjectsCard(Map<String, dynamic> projects) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: getRoleColor(projects['proyecto']['status']),
          child: Text(projects['proyecto']['status'] == true ? 'A' : 'I', style: const TextStyle(color: Colors.white),),
        ),
        title: Text(projects['proyecto']['title'], style: TextStyle(color: appColors[0])),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              projects['proyecto']['description'] ?? 'Vacío',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String,dynamic>>>(
              future: getProjectParticipants(projects['proyecto']['id'],),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox();
                }
                final participants = snapshot.data!;
                if (participants.isEmpty) {
                  return const SizedBox();
                }
                final leader = participants.where((e) => e['role'] == 'Líder',);
                final members = participants.where((e) => e['role'] == 'Integrante',);
                return Wrap(
                  spacing: 0,
                  runSpacing: 0,
                  children: [
                    ...leader.map((participant) {
                      final intern = participant['practicantes'];
                      return participantAvatar(
                        intern: intern,
                        color: appColors[0],
                        role: 'Líder',
                      );
                    }),
                    ...members.map((participant) {
                      final intern = participant['practicantes'];
                      return participantAvatar(
                        intern: intern,
                        role: 'Integrante',
                        color: Colors.green,
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectKanbanScreen(
                project: projects['proyecto'],
                myRole: projects['role'],
              ),
            ),
          );
        }
      ),
    );
  }

  Future<List<Map<String,dynamic>>> loadColumns(
      int projectId,
      ) async {

    final response = await supabase
        .from('kanban_columnas')
        .select()
        .eq('proyecto_id', projectId)
        .eq('status', true)
        .order('position');

    return List<Map<String,dynamic>>.from(response);
  }

  Future<List<Map<String,dynamic>>> loadTasks(
      int projectId,
      ) async {

    final response = await supabase
        .from('tareas')
        .select()
        .eq('proyecto_id', projectId)
        .eq('status', true)
        .order('created_at');

    return List<Map<String,dynamic>>.from(response);
  }


  Future<List<Map<String, dynamic>>> getProjectParticipants(int projectId) async {
    final response = await supabase
        .from('proyecto_participantes')
        .select('''
        *,
        practicantes(
          id,
          names,
          fathers_surname,
          mothers_surname,
          dni,
          phone_number,
          institutional_email,
          internship_start_date,
          internship_end_date
        )
      ''')
        .eq('proyecto_id', projectId);

    return List<Map<String, dynamic>>.from(response);
  }

  Widget participantAvatar({
    required Map<String, dynamic> intern,
    required Color color,
    required String role,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () {
        showInternDetails(intern, role);
      },
      child: Container(
        width: 35,
        height: 35,
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initials(intern),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String initials(Map<String,dynamic> intern) {
    final name = intern['names'] ?? '';
    final father = intern['fathers_surname'] ?? '';
    return '${name.isNotEmpty ? name[0] : ''}''${father.isNotEmpty ? father[0] : ''}';
  }

  void showInternDetails(Map<String, dynamic> intern, String role) {
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
              Text('${intern['names']} ${intern['fathers_surname']} ${intern['mothers_surname']}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),
              ),
              Text(
                role,
                style: TextStyle(
                  color: role == 'Líder'
                      ? appColors[0]
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              infoTile('DNI', intern['dni']),
              infoTile('Teléfono', intern['phone_number']),
              infoTile('Correo', intern['institutional_email']),
              infoTile('Inicio', intern['internship_start_date']),
              infoTile('Fin', intern['internship_end_date']),
              infoTile('Rol', role),
            ],
          ),
        );
      },
    );
  }

  Widget infoTile(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey,),),
          Text(value?.toString() ?? '', maxLines: 5,),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appColors[0],
        automaticallyImplyLeading: false,
        title: const Text('Proyectos', style: TextStyle(color: Colors.white, fontSize: 15),),
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(15),
        children: [
          ...projects.map(buildProjectsCard),
        ],
      ),
    );
  }

  Color getRoleColor(bool role) {
    switch(role) {
      case true: return Colors.blue;
      case false : return Colors.redAccent;
      default: return Colors.black12;
    }
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:innova/environments/custom.widgets.dart';
import 'package:innova/environments/environments.dart';
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

  Widget projectImage(String? url) {
    if (url == null || url.trim().isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.image_not_supported),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.broken_image),
        );
      },
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
      callback: (_) async {
        await loadProjects();
      },
    ).subscribe();

    participantsChannel = supabase.channel('participants_changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'proyecto_participantes',
      callback: (_) async {
        await loadProjects();
      },
    ).subscribe();
  }

  Future<void> loadParticipants(int projectId,) async {
    final response = await supabase
        .from('proyecto_participantes')
        .select('''
      *,
      practicantes(
        id,
        names,
        fathers_surname,
        mothers_surname
      )
    ''').eq('proyecto_id', projectId);

    projectParticipants = List<Map<String,dynamic>>.from(response);
  }

  Future<void> loadInterns() async {
    final response = await supabase
        .from('practicantes')
        .select()
        .order('names');
    interns = List<Map<String,dynamic>>.from(response);
  }

  Map<String,dynamic>? getLeader() {
    try {
      return projectParticipants.firstWhere((e) => e['role'] == 'Líder',);
    } catch (_) {
      return null;
    }
  }

  List<Map<String,dynamic>> getMembers() {
    return projectParticipants.where((e) => e['role'] == 'Integrante',).toList();
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

  Future<void> createProject() async {
    await supabase.from('proyecto').insert({
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'img_url': imageUrlController.text.trim(),
      'status': projectStatus,
    });
  }

  Future<void> updateProject(int projectId) async {
    await supabase.from('proyecto').update({
      'title': titleController.text.trim(),
      'description': descriptionController.text.trim(),
      'img_url': imageUrlController.text.trim(),
      'status': projectStatus,
    }).eq('id', projectId);
  }

  String initials(Map<String,dynamic> intern) {
    final name = intern['names'] ?? '';
    final father = intern['fathers_surname'] ?? '';
    return '${name.isNotEmpty ? name[0] : ''}''${father.isNotEmpty ? father[0] : ''}';
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

  Future<void> showParticipantsManager(Map<String, dynamic> project) async {
    await loadInterns();
    await loadParticipants(project['id']);
    selectedMembersIds.clear();
    selectedLeaderId = null;

    for (final participant in projectParticipants) {
      final internId = participant['practicante_id'];
      selectedMembersIds.add(internId);
      if (participant['role'] == 'Líder') {
        selectedLeaderId = internId;
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Participantes del Proyecto', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,),),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: interns.length,
                        itemBuilder: (_, index) {
                          final intern = interns[index];
                          final internId = intern['id'];
                          return CheckboxListTile(
                            value: selectedMembersIds.contains(internId),
                            title: Text('${intern['names']} ${intern['fathers_surname']}',),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  selectedMembersIds.add(internId,);
                                } else {
                                  selectedMembersIds.remove(internId,);
                                  if (selectedLeaderId == internId) {
                                    selectedLeaderId = null;
                                  }
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    DropdownButtonFormField<int>(
                      value: selectedLeaderId,
                      style: const TextStyle(fontWeight: FontWeight.normal),
                      decoration: const InputDecoration(labelText: 'Líder del proyecto',),
                      items: selectedMembersIds.map((id) {
                        final intern = interns.firstWhere((e) => e['id'] == id,);
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text('${intern['names']} ${intern['fathers_surname']}',),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedLeaderId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar Participantes',),
                        onPressed: () async {
                          try {
                            await saveParticipants(project['id']);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Participantes actualizados.'),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString(),),),
                            );
                            if (kDebugMode) {
                              print(e.toString());
                            }
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

  Future<void> loadProjects() async {
    final response = await supabase
        .from('proyecto')
        .select()
        .order('created_at', ascending: false,);

    setState(() {
      projects = List<Map<String,dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> showUsersForm({Map<String,dynamic>? project, bool isEdit = false}) async {
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
              title: isEdit == false ? 'Crear Proyecto' : 'Actualizar Proyecto',
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
                          labelText: 'Título',
                          labelStyle: TextStyle(fontSize: 10, color: Colors.black),
                          contentPadding: EdgeInsets.all(10),
                          border: InputBorder.none,
                        ),
                        controller: titleController,
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
                          labelText: 'Imagen',
                          labelStyle: TextStyle(fontSize: 10, color: Colors.black),
                          contentPadding: EdgeInsets.all(10),
                          border: InputBorder.none,
                        ),
                        controller: imageUrlController,
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
                        style: const TextStyle(fontSize: 10, color: Colors.black),
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          labelStyle: TextStyle(fontSize: 10, color: Colors.black),
                          contentPadding: EdgeInsets.all(10),
                          border: InputBorder.none,
                        ),
                        controller: descriptionController,
                        enabled: true,
                      ),
                    ),
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
                      await updateProject(project?['id']);
                    } else {
                      await createProject();
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
      floatingActionButton: FloatingActionButton(
        onPressed: showUsersForm,
        mini: true,
        backgroundColor: appColors[0],
        tooltip: 'Crear proyecto',
        hoverColor: const Color(0x52FFFFFF),
        child: const Icon(Icons.add, color: Colors.white,),
      ),
    );
  }

  Widget buildProjectsCard(Map<String, dynamic> projects) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: getRoleColor(projects['status']),
          child: Text(projects['status'] == true ? 'A' : 'I', style: const TextStyle(color: Colors.white),),
        ),
        title: Text(projects['title'], style: TextStyle(color: appColors[0])),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              projects['description'] ?? 'Vacío',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String,dynamic>>>(
              future: getProjectParticipants(projects['id'],),
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
        trailing: const Icon(Icons.arrow_forward_ios, size: 15, color: Colors.black,),
        onTap: () => showProjectDetails(projects),
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

  void showProjectDetails(Map<String, dynamic> projects) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 200,
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: NetworkImage(projects['img_url'] ?? ''),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Flexible(
                    child: SizedBox(
                      height: 300,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${projects['title']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,),),
                              const SizedBox(height: 20),
                              infoTile('Descripción', projects['description'],),
                            ],
                          ),
                          const SizedBox(height: 20),
                          FutureBuilder<List<Map<String,dynamic>>>(
                            future: getProjectParticipants(projects['id'],),
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
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (leader.isNotEmpty) ...[
                                    Row(
                                      children:
                                      leader.map((participant) {
                                        final intern = participant['practicantes'];
                                        return participantAvatar(
                                          intern: intern,
                                          color: appColors[0],
                                          role: 'Líder',
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                  if (members.isNotEmpty) ...[
                                    Wrap(
                                      children: members.map((participant) {
                                        final intern = participant['practicantes'];
                                        return participantAvatar(
                                          intern: intern,
                                          color: Colors.green,
                                          role: 'Integrante',
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await showParticipantsManager(
                          projects,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Integrantes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await showUsersForm(project: projects, isEdit: true);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) {
                            return AlertDialog(
                              title: const Text('Eliminar Registro', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,),),
                              content: const Text('¿Desea continuar?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false,),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            );
                          },
                        );
                        if (confirm == true) {
                          await deleteProject(projects['id']);
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

  Future<void> saveParticipants(int projectId) async {
    if (selectedLeaderId == null) {
      throw Exception('Debe seleccionar un líder');
    }
    await supabase.from('proyecto_participantes').delete().eq('proyecto_id', projectId);
    await supabase.from('proyecto_participantes').insert({
      'proyecto_id': projectId,
      'practicante_id': selectedLeaderId,
      'role': 'Líder',
    });
    for (final memberId in selectedMembersIds) {
      if (memberId == selectedLeaderId) {
        continue;
      }
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
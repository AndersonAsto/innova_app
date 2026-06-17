import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';
import 'package:innova/intern/projectKanbanScreen.dart';
import 'package:innova/login/authGate.dart';
import 'package:innova/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data' as typed;

class ProjectsInternScreen extends StatefulWidget {
  const ProjectsInternScreen({super.key});

  @override
  State<ProjectsInternScreen> createState() => _ProjectsInternScreenState();
}

class _ProjectsInternScreenState extends State<ProjectsInternScreen> {
  List<Map<String, dynamic>> projects = [];
  bool isLoading = true;
  RealtimeChannel? _projectsChannel;
  TextEditingController documentSearchController = TextEditingController();
  TextEditingController documentFileNameController = TextEditingController();
  List<Map<String, dynamic>> projectDocuments = [];
  bool isLoadingDocuments = false;
  String documentSearch = '';
  RealtimeChannel? _documentsChannel;
  int? currentDocumentsProjectId;
  StateSetter? documentsModalSetState;
  final TextEditingController invitationCodeController = TextEditingController();
  RealtimeChannel? _tasksChannel;
  RealtimeChannel? _columnsChannel;

  static const Color _primary     = Color(0xFF1A3A6B);
  static const Color _accent      = Color(0xFF2EC4B6);
  static const Color _leaderColor = Color(0xFF1A3A6B);
  static const Color _memberColor = Color(0xFF2EC4B6);
  static const Color _bgLight     = Color(0xFFF4F6FA);

  @override
  void initState() {
    super.initState();
    loadProjects();
    setupRealtimeSubscription();
    setupBoardRealtimeSubscription();
  }

  @override
  void dispose() {
    if (_projectsChannel != null) {
      supabase.removeChannel(_projectsChannel!);
    }
    if (_documentsChannel != null) {
      supabase.removeChannel(_documentsChannel!);
    }
    documentsModalSetState = null;
    invitationCodeController.dispose();
    documentSearchController.dispose();
    documentFileNameController.dispose();
    if (_tasksChannel != null) {
      supabase.removeChannel(_tasksChannel!);
    }

    if (_columnsChannel != null) {
      supabase.removeChannel(_columnsChannel!);
    }
    super.dispose();
  }

  void setupBoardRealtimeSubscription() {
    _tasksChannel = supabase
        .channel('projects_tasks_realtime')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tareas',
      callback: (_) async {
        await loadProjects();
      },
    )
        .subscribe();

    _columnsChannel = supabase
        .channel('projects_columns_realtime')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kanban_columnas',
      callback: (_) async {
        await loadProjects();
      },
    )
        .subscribe();
  }

  Future<void> joinProjectByInvitationCode() async {
    final code = invitationCodeController.text.trim();

    if (code.isEmpty) {
      throw Exception('Ingrese el código de invitación');
    }

    final myId = SessionService.profile!['id'];

    final invitation = await supabase
        .from('invitaciones_proyecto')
        .select()
        .eq('token', code)
        .eq('status', true)
        .maybeSingle();

    if (invitation == null) {
      throw Exception('El código no existe o ya no está activo');
    }

    if (invitation['used_by_practicante'] != null) {
      throw Exception('Este código ya fue usado');
    }

    final expiresAt = invitation['expires_at'];

    if (expiresAt != null) {
      final expiration = DateTime.parse(expiresAt);
      if (DateTime.now().isAfter(expiration)) {
        throw Exception('Este código ya expiró');
      }
    }

    final projectId = invitation['proyecto_id'];

    final existing = await supabase
        .from('proyecto_participantes')
        .select()
        .eq('proyecto_id', projectId)
        .eq('practicante_id', myId)
        .maybeSingle();

    if (existing != null) {
      if (existing['role'] == 'Líder') {
        throw Exception('Ya eres líder de este proyecto');
      }

      throw Exception('Ya perteneces a este proyecto');
    }

    await supabase.from('proyecto_participantes').insert({
      'proyecto_id': projectId,
      'practicante_id': myId,
      'role': 'Integrante',
      'status': true,
    });

    await supabase.from('invitaciones_proyecto').update({
      'status': false,
      'used_by_practicante': myId,
      'used_at': DateTime.now().toIso8601String(),
    }).eq('id', invitation['id']);

    await loadProjects();
  }

  Future<void> showJoinProjectModal() async {
    invitationCodeController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.group_add_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Unirse a proyecto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: invitationCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Código de invitación',
                  hintText: 'INV-XXXXXXXX',
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text('Unirme'),
                  onPressed: () async {
                    try {
                      await joinProjectByInvitationCode();

                      if (!mounted) return;

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Te uniste al proyecto correctamente'),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> loadProjectDocuments(int projectId) async {
    setState(() {
      isLoadingDocuments = true;
    });

    final response = await supabase
        .from('documentos_proyecto')
        .select('''
        *,
        practicantes(
          id,
          names,
          fathers_surname
        )
      ''')
        .eq('proyecto_id', projectId)
        .eq('status', true)
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      projectDocuments = List<Map<String, dynamic>>.from(response);
      isLoadingDocuments = false;
    });
  }

  List<Map<String, dynamic>> filteredDocuments() {
    final query = documentSearch.toLowerCase().trim();

    if (query.isEmpty) {
      return projectDocuments;
    }

    return projectDocuments.where((doc) {
      final name = doc['file_name']?.toString().toLowerCase() ?? '';
      return name.contains(query);
    }).toList();
  }

  Color fileTypeColor(String type) {
    final ext = type.toLowerCase();

    if (ext.contains('pdf')) return Colors.red;
    if (ext.contains('doc')) return Colors.blue;
    if (ext.contains('xls')) return Colors.green;
    if (ext.contains('ppt')) return Colors.orange;
    if (ext.contains('image') ||
        ext.contains('jpg') ||
        ext.contains('jpeg') ||
        ext.contains('png') ||
        ext.contains('webp')) {
      return Colors.purple;
    }

    return Colors.grey;
  }

  IconData fileTypeIcon(String type) {
    final ext = type.toLowerCase();

    if (ext.contains('pdf')) return Icons.picture_as_pdf;
    if (ext.contains('doc')) return Icons.description;
    if (ext.contains('xls')) return Icons.table_chart;
    if (ext.contains('ppt')) return Icons.slideshow;
    if (ext.contains('image') ||
        ext.contains('jpg') ||
        ext.contains('jpeg') ||
        ext.contains('png') ||
        ext.contains('webp')) {
      return Icons.image;
    }

    return Icons.insert_drive_file;
  }

  String fileExtension(String fileName) {
    if (!fileName.contains('.')) return 'file';
    return fileName.split('.').last.toLowerCase();
  }

  Future<void> downloadDocument(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('No se pudo abrir el archivo');
    }
  }

  Future<void> uploadProjectDocument(Map<String, dynamic> project) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final typed.Uint8List? bytes = file.bytes;

    if (bytes == null) {
      throw Exception('No se pudo leer el archivo');
    }

    final originalName = file.name;
    final ext = fileExtension(originalName);
    final cleanName = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    final storagePath = '${project['id']}/${DateTime.now().millisecondsSinceEpoch}_$cleanName';

    await supabase.storage
        .from('project-documents')
        .uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: file.extension == null ? null : 'application/$ext',
        upsert: false,
      ),
    );

    final publicUrl = supabase.storage
        .from('project-documents')
        .getPublicUrl(storagePath);

    await supabase.from('documentos_proyecto').insert({
      'proyecto_id': project['id'],
      'uploaded_by_practicante': SessionService.profile!['id'],
      'file_name': originalName,
      'file_url': publicUrl,
      'storage_path': storagePath,
      'file_size_mb': ((file.size / 1024) / 1024).toStringAsFixed(2),
      'file_type': ext,
      'status': true,
    });

    await loadProjectDocuments(project['id']);
  }

  Future<void> deleteProjectDocument(Map<String, dynamic> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(10),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child:
                const Icon(Icons.delete, color: _primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Eliminar Documento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primary,),),
            ],
          ),
          content: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('¿Desea eliminar definitivamente "${doc['file_name']}"?',
                    style: TextStyle(fontSize: 11, height: 1.35, color: Colors.orange.shade800,),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey),),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final storagePath = doc['storage_path'];

    if (storagePath != null && storagePath.toString().isNotEmpty) {
      await supabase.storage
          .from('project-documents')
          .remove([storagePath]);
    }

    await supabase
        .from('documentos_proyecto')
        .delete()
        .eq('id', doc['id']);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Documento eliminado correctamente'),
      ),
    );
  }

  Future<void> showProjectDocumentsModal({
    required Map<String, dynamic> project,
    required bool isLeader,
  }) async {
    documentSearchController.clear();
    documentSearch = '';

    await loadProjectDocuments(project['id']);
    subscribeDocumentsRealtime(project['id']);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(

          builder: (context, setModalState) {
            final docs = filteredDocuments();
            documentsModalSetState = setModalState;
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.folder_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Documentos - ${project['title']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E5E3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: documentSearchController,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A1A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre de archivo...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: Colors.grey.shade500,
                          ),
                          suffixIcon: documentSearch.isNotEmpty
                              ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: () {
                              setModalState(() {
                                documentSearchController.clear();
                                documentSearch = '';
                              });
                            },
                          ) : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 13,
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            documentSearch = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isLeader)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await uploadProjectDocument(project);
                              setModalState(() {});
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Documento subido correctamente'),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.upload_file, color: Colors.white,),
                          label: const Text('Subir documento'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),

                    if (isLeader) const SizedBox(height: 12),

                    Expanded(
                      child: isLoadingDocuments
                          ? const Center(child: CircularProgressIndicator())
                          : docs.isEmpty
                          ? const Center(
                        child: Text('No hay documentos disponibles'),
                      )
                          : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (_, index) {
                          return buildDocumentCard(docs[index], isLeader);
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

  Widget buildDocumentCard(Map<String, dynamic> doc, bool isLeader) {
    final type = doc['file_type']?.toString() ?? '';
    final color = fileTypeColor(type);
    final uploader = doc['practicantes'];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            fileTypeIcon(type),
            color: color,
          ),
        ),
        title: Text(
          doc['file_name'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${doc['file_size_mb']} MB · ${type.toUpperCase()}',
              style: const TextStyle(fontSize: 11),
            ),
            if (uploader != null)
              Text(
                'Subido por ${uploader['names']} ${uploader['fathers_surname']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Descargar',
              icon: const Icon(
                Icons.download_rounded,
                color: _primary,
              ),
              onPressed: () async {
                try {
                  await downloadDocument(doc['file_url']);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                    ),
                  );
                }
              },
            ),
            if (isLeader)...[
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(
                  Icons.delete_rounded,
                  color: Colors.red,
                ),
                onPressed: () async {
                  try {
                    await deleteProjectDocument(doc);
                    await loadProjectDocuments(doc['proyecto_id']);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                      ),
                    );
                  }
                },
              ),
            ]
          ],
        ),
      ),
    );
  }

  void setupRealtimeSubscription() {
    final internId = SessionService.profile!['id'];

    _projectsChannel = supabase
        .channel('projects_intern_$internId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'proyecto_participantes',
      callback: (_) async {
        await loadProjects();
      },
    )
        .subscribe();
  }

  void subscribeDocumentsRealtime(int projectId) {
    if (_documentsChannel != null) {
      supabase.removeChannel(_documentsChannel!);
    }

    currentDocumentsProjectId = projectId;

    _documentsChannel = supabase
        .channel('documents_project_$projectId')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'documentos_proyecto',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'proyecto_id',
        value: projectId,
      ),
      callback: (_) async {
        await loadProjectDocuments(projectId);
        documentsModalSetState?.call(() {});
      },
    )
        .subscribe();
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectKanbanScreen(project: project, myRole: myRole),),),
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
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text(isActive ? 'Activo' : 'Inactivo', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                              Text('${participants.length} miembro${participants.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Spacer(),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              showProjectDocumentsModal(
                                project: project,
                                isLeader: isLeader,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.folder_rounded,
                                    size: 16,
                                    color: _primary,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Documentos',
                                    style: TextStyle(
                                      color: _primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: screenWidth > 700 ? AppBar(
        backgroundColor: appColors[0],
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text('Proyectos', style: TextStyle(color: Colors.white, fontSize: 15),),
            const SizedBox(width: 10,),
            Text('(${projects.length} proyectos · $activeCount activos)', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
          ],
        )
      ) : null ,
      body: CustomScrollView(
        slivers: [
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        onPressed: showJoinProjectModal,
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: const Text('Unirme'),
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
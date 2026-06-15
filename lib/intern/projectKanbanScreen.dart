import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:innova/environments/environments.dart';
import 'package:innova/login/authGate.dart';
import 'package:innova/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectKanbanScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final String myRole;

  const ProjectKanbanScreen({
    super.key,
    required this.project,
    required this.myRole,
  });

  @override
  State<ProjectKanbanScreen> createState() => _ProjectKanbanScreenState();
}

class _ProjectKanbanScreenState extends State<ProjectKanbanScreen> {
  RealtimeChannel? channel;
  List<Map<String, dynamic>> columns = [];
  List<Map<String, dynamic>> tasks   = [];
  bool isLoading = true;
  final TextEditingController subColumnNameController = TextEditingController();
  Map<String, dynamic>? selectedParentColumn;
  final TextEditingController taskTitleController = TextEditingController();
  final TextEditingController taskDescriptionController = TextEditingController();
  final ScrollController horizontalBoardController = ScrollController();
  final ScrollController verticalBoardController = ScrollController();
  List<Map<String, dynamic>> activeUsers = [];
  RealtimeChannel? activeUsersChannel;

  Timer? activeUserTimer;

  // ─── Paleta Notion-like ───────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF1A3A6B);
  static const Color _bgPage   = Color(0xFFF7F7F5);   // fondo página Notion
  static const Color _bgColumn = Color(0xFFF0F0EE);   // fondo columna
  static const Color _border   = Color(0xFFE5E5E3);

  // Colores de estado — pasteles suaves
  static const Map<String, Color> _colColors = {
    'pendiente':  Color(0xFFFFF3CD),
    'en proceso': Color(0xFFD6EAF8),
    'terminado':  Color(0xFFD5F5E3),
  };
  static const Map<String, Color> _colDotColors = {
    'pendiente':  Color(0xFFE59D00),
    'en proceso': Color(0xFF2980B9),
    'terminado':  Color(0xFF27AE60),
  };
  static const Map<String, Color> _colTextColors = {
    'pendiente':  Color(0xFF7A5800),
    'en proceso': Color(0xFF1A5276),
    'terminado':  Color(0xFF1A6636),
  };

  @override
  void initState() {
    super.initState();
    loadBoard();
    subscribeRealtime();
    loadActiveUsers();
    setActiveUser();
    subscribeActiveUsersRealtime();
    setActiveUser();
    startActiveUserHeartbeat();
  }

  @override
  void dispose() {
    if (channel != null) supabase.removeChannel(channel!);
    taskTitleController.dispose();
    taskDescriptionController.dispose();
    subColumnNameController.dispose();
    horizontalBoardController.dispose();
    verticalBoardController.dispose();
    if (activeUsersChannel != null) {
      supabase.removeChannel(activeUsersChannel!);
    }
    activeUserTimer?.cancel();
    removeActiveUser();
    super.dispose();
  }

  Future<void> setActiveUser() async {
    await supabase.from('proyecto_usuarios_activos').upsert({
      'proyecto_id': widget.project['id'],
      'practicante_id': SessionService.profile!['id'],
      'last_seen': DateTime.now().toIso8601String(),
    }, onConflict: 'proyecto_id,practicante_id');
  }

  Future<void> removeActiveUser() async {
    await supabase
        .from('proyecto_usuarios_activos')
        .delete()
        .eq('proyecto_id', widget.project['id'])
        .eq('practicante_id', SessionService.profile!['id']);
  }

  void startActiveUserHeartbeat() {
    activeUserTimer?.cancel();

    activeUserTimer = Timer.periodic(
      const Duration(seconds: 25),
          (_) async {
        await setActiveUser();
      },
    );
  }

  Future<void> loadActiveUsers() async {
    final limit = DateTime.now()
        .subtract(const Duration(seconds: 60))
        .toIso8601String();

    final response = await supabase
        .from('proyecto_usuarios_activos')
        .select('''
        *,
        practicantes(
          id,
          names,
          fathers_surname
        )
      ''')
        .eq('proyecto_id', widget.project['id'])
        .gte('last_seen', limit);

    if (!mounted) return;

    setState(() {
      activeUsers = List<Map<String, dynamic>>.from(response);
    });
  }

  void subscribeActiveUsersRealtime() {
    activeUsersChannel = supabase
        .channel('active_users_${widget.project['id']}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'proyecto_usuarios_activos',
      callback: (_) async {
        await loadActiveUsers();
      },
    )
        .subscribe();
  }

  Color userColor(int id) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
    ];

    return colors[id % colors.length];
  }

  String initials(Map<String, dynamic> user) {
    final name = user['names'] ?? '';
    final father = user['fathers_surname'] ?? '';

    return '${name.isNotEmpty ? name[0] : ''}${father.isNotEmpty ? father[0] : ''}';
  }

  Widget activeUsersBar() {
    if (activeUsers.isEmpty) return const SizedBox();

    final visibleUsers = activeUsers.take(5).toList();
    final extraCount = activeUsers.length - visibleUsers.length;

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 180,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...visibleUsers.map((item) {
            final user = item['practicantes'];
            final id = user['id'];

            return Container(
              margin: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: '${user['names']} ${user['fathers_surname']}',
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: userColor(id),
                  child: Text(
                    initials(user),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),

          if (extraCount > 0)
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade600,
              child: Text(
                '+$extraCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool get isLeader => widget.myRole == 'Líder';

  List<Map<String, dynamic>> get baseColumns {
    return columns
        .where((c) => c['parent_column_id'] == null)
        .toList();
  }

  List<Map<String, dynamic>> childColumnsOf(int parentId) {
    return columns
        .where((c) => c['parent_column_id'] == parentId)
        .toList()
      ..sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
  }

  List<Map<String, dynamic>> get orderedColumns {
    final ordered = <Map<String, dynamic>>[];

    final bases = [...baseColumns]
      ..sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));

    for (final base in bases) {
      ordered.add(base);
      ordered.addAll(childColumnsOf(base['id']));
    }

    return ordered;
  }

  Map<String, dynamic>? findBaseColumnByName(String name) {
    try {
      return baseColumns.firstWhere(
            (c) => c['name'].toString().toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  int maxSubColumnsForParent(String parentName) {
    final name = parentName.toLowerCase();

    if (name == 'en proceso') return 2;
    if (name == 'terminado') return 1;

    return 0;
  }

  List<Map<String, dynamic>> availableParentsForSubColumn() {
    final enProceso = findBaseColumnByName('En Proceso');
    final terminado = findBaseColumnByName('Terminado');

    final available = <Map<String, dynamic>>[];

    if (enProceso != null) {
      final current = childColumnsOf(enProceso['id']).length;
      if (current < 2) {
        available.add(enProceso);
      }
    }

    if (terminado != null) {
      final current = childColumnsOf(terminado['id']).length;
      if (current < 1) {
        available.add(terminado);
      }
    }

    return available;
  }

  Future<void> showCreateSubColumnDialog() async {
    subColumnNameController.clear();
    selectedParentColumn = null;

    final parents = availableParentsForSubColumn();

    if (parents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya se alcanzó el máximo de subcolumnas para este proyecto'),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Nueva subcolumna',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedParentColumn,
                      decoration: const InputDecoration(
                        labelText: 'Columna principal',
                        border: OutlineInputBorder(),
                      ),
                      items: parents.map((parent) {
                        final current = childColumnsOf(parent['id']).length;
                        final max = maxSubColumnsForParent(parent['name']);

                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: parent,
                          child: Text(
                            '${parent['name']} ($current/$max)',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedParentColumn = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _dialogField(
                      'Nombre de subcolumna',
                      subColumnNameController,
                      Icons.view_column_rounded,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Límites: En Proceso permite 2 subcolumnas. Terminado permite 1 subcolumna.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await createSubColumn();

                      if (!mounted) return;

                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subcolumna creada correctamente'),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int nextSubColumnPosition(Map<String, dynamic> parent) {
    final children = childColumnsOf(parent['id']);

    if (children.isEmpty) {
      return ((parent['position'] ?? 0) * 100) + 1;
    }

    final positions = children
        .map((e) => e['position'] ?? 0)
        .cast<int>()
        .toList()
      ..sort();

    return positions.last + 1;
  }

  Future<void> createSubColumn() async {
    if (!isLeader) {
      throw Exception('Sólo el líder puede crear subcolumnas');
    }

    final parent = selectedParentColumn;

    if (parent == null) {
      throw Exception('Seleccione una columna principal');
    }

    final name = subColumnNameController.text.trim();

    if (name.isEmpty) {
      throw Exception('Ingrese el nombre de la subcolumna');
    }

    final currentChildren = childColumnsOf(parent['id']);
    final limit = maxSubColumnsForParent(parent['name']);

    if (currentChildren.length >= limit) {
      throw Exception('Ya se alcanzó el límite de subcolumnas');
    }

    await supabase.from('kanban_columnas').insert({
      'proyecto_id': widget.project['id'],
      'name': name,
      'position': nextSubColumnPosition(parent),
      'parent_column_id': parent['id'],
      'is_default': false,
      'status': true,
    });

    subColumnNameController.clear();
    selectedParentColumn = null;
  }

  void subscribeRealtime() {
    channel = supabase
        .channel('kanban_project_${widget.project['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, schema: 'public', table: 'tareas',
          callback: (_) async => await loadBoard(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all, schema: 'public', table: 'kanban_columnas',
          callback: (_) async => await loadBoard(),
        )
        .subscribe();
  }

  Future<void> loadBoard() async {
    final projectId = widget.project['id'];
    final columnsRes = await supabase
        .from('kanban_columnas').select()
        .eq('proyecto_id', projectId).eq('status', true)
        .order('position', ascending: true);
    final tasksRes = await supabase
        .from('tareas').select()
        .eq('proyecto_id', projectId).eq('status', true)
        .order('position_in_column', ascending: true)
        .order('created_at', ascending: true);
    if (!mounted) return;
    setState(() {
      columns = List<Map<String, dynamic>>.from(columnsRes);
      tasks   = List<Map<String, dynamic>>.from(tasksRes);
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> tasksByColumn(int columnId) => tasks.where((t) => t['column_id'] == columnId).toList();

  Map<String, dynamic>? getPendingColumn() {
    try {
      return columns.firstWhere((c) => c['name'].toString().toLowerCase() == 'pendiente');
    } catch (_) { return null; }
  }

  int nextPositionInColumn(int columnId) {
    final ct = tasksByColumn(columnId);
    if (ct.isEmpty) return 1;
    final positions = ct.map((t) => t['position_in_column'] ?? 0).cast<int>().toList()..sort();
    return positions.last + 1;
  }

  // ─── Crear tarea ──────────────────────────────────────────────────────────
  Future<void> showCreateTaskDialog() async {
    taskTitleController.clear();
    taskDescriptionController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: _primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.add_task_rounded, color: _primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Nueva actividad', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primary)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            children: [
              _dialogField('Título', taskTitleController, Icons.title_rounded),
              const SizedBox(height: 10),
              _dialogField('Descripción', taskDescriptionController, Icons.notes_rounded, maxLines: 3),
              const SizedBox(height: 10),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final nav       = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await createTask();
                nav.pop();
                messenger.showSnackBar(const SnackBar(content: Text('Actividad creada')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: _bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          icon: Icon(icon, size: 16, color: Colors.grey),
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Future<void> createTask() async {
    final title = taskTitleController.text.trim();
    if (title.isEmpty) throw Exception('El título es obligatorio');
    final pendingColumn = getPendingColumn();
    if (pendingColumn == null) throw Exception('No existe la columna Pendiente');
    final pendingColumnId = pendingColumn['id'];
    await supabase.from('tareas').insert({
      'proyecto_id': widget.project['id'],
      'column_id': pendingColumnId,
      'title': title,
      'description': taskDescriptionController.text.trim(),
      'position_in_column': nextPositionInColumn(pendingColumnId),
      'status': true,
    });
  }

  Future<bool> lockTask(Map<String, dynamic> task) async {
    final myId = SessionService.profile!['id'];
    final lockedBy = task['locked_by_practicante'];
    if (lockedBy != null && lockedBy != myId) return false;
    await supabase.from('tareas').update({
      'locked_by_practicante': myId,
      'locked_at': DateTime.now().toIso8601String(),
    }).eq('id', task['id']);
    return true;
  }

  Future<void> unlockTask(Map<String, dynamic> task) async {
    final myId = SessionService.profile!['id'];
    await supabase.from('tareas').update({
      'locked_by_practicante': null,
      'locked_at': null,
    }).eq('id', task['id']).eq('locked_by_practicante', myId);
  }

  Future<void> moveTaskToColumn(Map<String, dynamic> task, int targetColumnId) async {
    final myId = SessionService.profile!['id'];
    await supabase.from('tareas').update({
      'column_id': targetColumnId,
      'position_in_column': nextPositionInColumn(targetColumnId),
      'locked_by_practicante': null,
      'locked_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', task['id']).eq('locked_by_practicante', myId);
  }

  bool isTaskLockedByOther(Map<String, dynamic> task) {
    final myId = SessionService.profile!['id'];
    final lockedBy = task['locked_by_practicante'];
    return lockedBy != null && lockedBy != myId;
  }

  Map<String, dynamic>? activeUserById(int id) {
    try {
      return activeUsers.firstWhere(
            (e) => e['practicante_id'] == id,
      );
    } catch (_) {
      return null;
    }
  }

  Color taskLockColor(Map<String, dynamic> task) {
    final lockedBy = task['locked_by_practicante'];

    if (lockedBy == null) {
      return _border;
    }

    return userColor(lockedBy);
  }

  String taskLockedByName(Map<String, dynamic> task) {
    final lockedBy = task['locked_by_practicante'];

    if (lockedBy == null) {
      return '';
    }

    final active = activeUserById(lockedBy);

    if (active == null || active['practicantes'] == null) {
      return 'Usuario moviendo';
    }

    final user = active['practicantes'];

    return '${user['names']} ${user['fathers_surname']}';
  }

  // ─── Colores de columna ───────────────────────────────────────────────────
  Color _colBg(String name) => _colColors[name.toLowerCase()] ?? const Color(0xFFEDE7F6);
  Color _colDot(String name) => _colDotColors[name.toLowerCase()] ?? const Color(0xFF6A1B9A);
  Color _colText(String name) => _colTextColors[name.toLowerCase()] ?? const Color(0xFF4A148C);

  // ─── Columna estilo Notion ────────────────────────────────────────────────
  Widget buildColumn(Map<String, dynamic> column) {
    final columnTasks = tasksByColumn(column['id']);
    final bg   = _colBg(column['name']);
    final dot  = _colDot(column['name']);
    final text = _colText(column['name']);
    final isMobile = MediaQuery.of(context).size.width < 750;

    final isChildColumn = column['parent_column_id'] != null;

    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (task) => task != null && !isTaskLockedByOther(task),
      onAccept:     (task) async => await moveTaskToColumn(task, column['id']),
      builder: (context, candidateData, _) {
        final isDragOver = candidateData.isNotEmpty;

        final header = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isChildColumn ? '↳ ${column['name']}' : column['name'],
                    style: TextStyle(
                      fontSize: isChildColumn ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: text,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                    child: Text('${columnTasks.length}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: dot)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5E3)),
          ],
        );

        final emptyState = Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.inbox_rounded, size: 15, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('Sin actividades',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ],
          ),
        );

        final decoration = BoxDecoration(
          color: isDragOver ? bg.withValues(alpha: 0.6) : _bgColumn,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDragOver ? dot : _border, width: isDragOver ? 2 : 1),
        );

        if (isMobile) {
          // Móvil: altura natural, el ListView padre se encarga del scroll
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: decoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                if (columnTasks.isEmpty) emptyState,
                ...columnTasks.map(buildTaskCard),
                const SizedBox(height: 8),
              ],
            ),
          );
        }

        // Desktop: columna con scroll interno, ocupa todo el alto disponible
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 300,
          height: double.infinity,
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              if (columnTasks.isEmpty) emptyState,
              if (columnTasks.isNotEmpty)
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 8),
                    children: columnTasks.map(buildTaskCard).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Tarjeta estilo Notion ────────────────────────────────────────────────
  Widget buildTaskCard(Map<String, dynamic> task) {
    final locked = isTaskLockedByOther(task);
    final lockedBy = task['locked_by_practicante'];
    final lockColor = taskLockColor(task);
    final lockName = taskLockedByName(task);

    final card = Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: lockedBy != null ? lockColor : _border,
          width: lockedBy != null ? 2 : 1,
        ),
        boxShadow: lockedBy != null
            ? [
          BoxShadow(
            color: lockColor.withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ]
            : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lockedBy != null) ...[
            Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: lockColor,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    locked
                        ? 'Moviendo: $lockName'
                        : 'Moviendo tú',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: lockColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title'],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: locked ? Colors.grey : const Color(0xFF1A1A1A),
                      ),
                    ),
                    if ((task['description'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        task['description'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(
                  locked ? Icons.lock_rounded : Icons.more_vert,
                  size: 18,
                  color: locked ? Colors.grey.shade400 : Colors.grey.shade500,
                ),
                enabled: !locked,
                onSelected: (value) async {
                  if (value == 'edit') {
                    await showEditTaskDialog(task);
                  }

                  if (value == 'delete') {
                    await deleteTask(task);
                  }
                },
                itemBuilder: (_) {
                  return const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                  ];
                },
              ),
            ],
          ),
        ],
      ),
    );

    if (locked) return card;

    return LongPressDraggable<Map<String, dynamic>>(
      data: task,
      onDragStarted: () async => await lockTask(task),
      onDragEnd: (_) async {
        await unlockTask(task);
        await loadBoard();
      },
      onDraggableCanceled: (_, __) async => await unlockTask(task),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 280,
          child: Opacity(
            opacity: 0.95,
            child: card,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: card,
      ),
      child: card,
    );
  }

  Future<void> showEditTaskDialog(Map<String, dynamic> task) async {
    taskTitleController.text = task['title'] ?? '';
    taskDescriptionController.text = task['description'] ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Editar actividad',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                _dialogField(
                  'Título',
                  taskTitleController,
                  Icons.title_rounded,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  'Descripción',
                  taskDescriptionController,
                  Icons.notes_rounded,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  await updateTask(task['id']);

                  if (!mounted) return;

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Actividad actualizada'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  String generateInvitationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();

    final code = List.generate(
      8,
          (_) => chars[random.nextInt(chars.length)],
    ).join();

    return 'INV-$code';
  }

  Future<void> generateInvitation() async {
    if (!isLeader) {
      throw Exception('Sólo el líder puede generar invitaciones');
    }

    final code = generateInvitationCode();

    await supabase.from('invitaciones_proyecto').insert({
      'proyecto_id': widget.project['id'],
      'created_by_practicante': SessionService.profile!['id'],
      'token': code,
      'status': true,
      'expires_at': DateTime.now()
          .add(const Duration(days: 7))
          .toIso8601String(),
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Código de invitación',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Comparte este código con un practicante registrado para que pueda unirse al proyecto.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Center(
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: _primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: code),
                );

                if (!mounted) return;

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código copiado'),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copiar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateTask(int taskId) async {
    final title = taskTitleController.text.trim();

    if (title.isEmpty) {
      throw Exception('El título es obligatorio');
    }

    await supabase.from('tareas').update({
      'title': title,
      'description': taskDescriptionController.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
  }

  Future<void> deleteTask(Map<String, dynamic> task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Eliminar actividad',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text('¿Desea eliminar esta actividad?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
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

    if (confirm != true) return;

    await supabase.from('tareas').update({
      'status': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', task['id']);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Actividad eliminada'),
      ),
    );
  }

  // ─── Pantalla principal ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: _bgPage,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(size: 20, color: Colors.white),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project['title'], style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3,),
            Text('Mi rol: ${widget.myRole}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
          children: [
            // ── Barra superior ───────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text('${tasks.length} actividades', style: TextStyle(fontSize: 12, color: Colors.grey.shade500,),),
                  activeUsersBar(),
                  ElevatedButton.icon(
                    onPressed: showCreateTaskDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text('Nueva actividad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),),
                  ),

                  if (isLeader)
                    ElevatedButton.icon(
                      onPressed: showCreateSubColumnDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.view_column_rounded, size: 16, color: Colors.white,),
                      label: const Text('Subcolumna', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5E3)),
            // ── Tablero ──────────────────────────────────────────
            Expanded(
              child: isMobile
                  ? ListView(
                padding: const EdgeInsets.all(8),
                children: orderedColumns.map(buildColumn).toList(),
              )
                  : LayoutBuilder(
                builder: (context, constraints) {
                  const columnWidth = 300.0;
                  const columnMargin = 16.0;

                  final boardWidth = orderedColumns.length * (columnWidth + columnMargin);

                  return Scrollbar(
                    controller: horizontalBoardController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: horizontalBoardController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: boardWidth < constraints.maxWidth
                            ? constraints.maxWidth
                            : boardWidth,
                        height: constraints.maxHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: orderedColumns.map(buildColumn).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      floatingActionButton: isLeader
          ? FloatingActionButton.extended(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          try {
            await generateInvitation();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()),),);
          }
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invitar'),
      ) : null,
    );
  }
}
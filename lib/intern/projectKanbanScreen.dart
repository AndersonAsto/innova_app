import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> tasks = [];

  bool isLoading = true;

  final TextEditingController taskTitleController = TextEditingController();
  final TextEditingController taskDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadBoard();
    subscribeRealtime();
  }

  @override
  void dispose() {
    if (channel != null) {
      supabase.removeChannel(channel!);
    }

    taskTitleController.dispose();
    taskDescriptionController.dispose();

    super.dispose();
  }

  void subscribeRealtime() {
    channel = supabase
        .channel('kanban_project_${widget.project['id']}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tareas',
      callback: (_) async {
        await loadBoard();
      },
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'kanban_columnas',
      callback: (_) async {
        await loadBoard();
      },
    )
        .subscribe();
  }

  Future<void> loadBoard() async {
    final projectId = widget.project['id'];

    final columnsResponse = await supabase
        .from('kanban_columnas')
        .select()
        .eq('proyecto_id', projectId)
        .eq('status', true)
        .order('position', ascending: true);

    final tasksResponse = await supabase
        .from('tareas')
        .select()
        .eq('proyecto_id', projectId)
        .eq('status', true)
        .order('position_in_column', ascending: true)
        .order('created_at', ascending: true);

    if (!mounted) return;

    setState(() {
      columns = List<Map<String, dynamic>>.from(columnsResponse);
      tasks = List<Map<String, dynamic>>.from(tasksResponse);
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> tasksByColumn(int columnId) {
    return tasks
        .where((task) => task['column_id'] == columnId)
        .toList();
  }

  Map<String, dynamic>? getPendingColumn() {
    try {
      return columns.firstWhere(
            (column) =>
        column['name'].toString().toLowerCase() == 'pendiente',
      );
    } catch (_) {
      return null;
    }
  }

  int nextPositionInColumn(int columnId) {
    final columnTasks = tasksByColumn(columnId);

    if (columnTasks.isEmpty) {
      return 1;
    }

    final positions = columnTasks
        .map((task) => task['position_in_column'] ?? 0)
        .cast<int>()
        .toList();

    positions.sort();

    return positions.last + 1;
  }

  Future<void> showCreateTaskDialog() async {
    taskTitleController.clear();
    taskDescriptionController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            'Nueva actividad',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: taskTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: taskDescriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
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
              onPressed: () async {
                try {
                  await createTask();

                  if (!mounted) return;

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Actividad creada correctamente'),
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
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> createTask() async {
    final title = taskTitleController.text.trim();
    final description = taskDescriptionController.text.trim();

    if (title.isEmpty) {
      throw Exception('El título de la actividad es obligatorio');
    }

    final pendingColumn = getPendingColumn();

    if (pendingColumn == null) {
      throw Exception('No existe la columna Pendiente para este proyecto');
    }

    final pendingColumnId = pendingColumn['id'];

    await supabase.from('tareas').insert({
      'proyecto_id': widget.project['id'],
      'column_id': pendingColumnId,
      'title': title,
      'description': description,
      'position_in_column': nextPositionInColumn(pendingColumnId),
      'status': true,
    });
  }

  Future<bool> lockTask(Map<String, dynamic> task) async {
    final myId = SessionService.profile!['id'];

    final lockedBy = task['locked_by_practicante'];

    if (lockedBy != null && lockedBy != myId) {
      return false;
    }

    await supabase
        .from('tareas')
        .update({
      'locked_by_practicante': myId,
      'locked_at': DateTime.now().toIso8601String(),
    })
        .eq('id', task['id']);

    return true;
  }

  Future<void> unlockTask(Map<String, dynamic> task) async {
    final myId = SessionService.profile!['id'];

    await supabase
        .from('tareas')
        .update({
      'locked_by_practicante': null,
      'locked_at': null,
    })
        .eq('id', task['id'])
        .eq('locked_by_practicante', myId);
  }

  Future<void> moveTaskToColumn(
      Map<String, dynamic> task,
      int targetColumnId,
      ) async {
    final myId = SessionService.profile!['id'];

    await supabase
        .from('tareas')
        .update({
      'column_id': targetColumnId,
      'position_in_column': nextPositionInColumn(targetColumnId),
      'locked_by_practicante': null,
      'locked_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', task['id'])
        .eq('locked_by_practicante', myId);
  }

  bool isTaskLockedByOther(Map<String, dynamic> task) {
    final myId = SessionService.profile!['id'];
    final lockedBy = task['locked_by_practicante'];

    return lockedBy != null && lockedBy != myId;
  }

  Color getColumnColor(String name) {
    switch (name.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'en proceso':
        return Colors.blue;
      case 'terminado':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }

  Widget buildColumn(Map<String, dynamic> column) {
    final columnTasks = tasksByColumn(column['id']);

    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (task) {
        if (task == null) return false;
        return !isTaskLockedByOther(task);
      },
      onAccept: (task) async {
        await moveTaskToColumn(
          task,
          column['id'],
        );
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 320,
          margin: const EdgeInsets.all(8),
          child: Card(
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: getColumnColor(column['name']),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    column['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (columnTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Sin actividades',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ...columnTasks.map(buildTaskCard),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildTaskCard(Map<String, dynamic> task) {
    final locked = isTaskLockedByOther(task);

    final taskCard = Card(
      margin: const EdgeInsets.all(8),
      color: locked ? Colors.grey.shade300 : Colors.white,
      child: ListTile(
        title: Text(
          task['title'],
          style: TextStyle(
            color: locked ? Colors.grey : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          task['description'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: locked
            ? const Icon(Icons.lock, size: 18)
            : const Icon(Icons.drag_indicator, size: 18),
      ),
    );

    if (locked) {
      return taskCard;
    }

    return LongPressDraggable<Map<String, dynamic>>(
      data: task,
      onDragStarted: () async {
        await lockTask(task);
      },
      onDragEnd: (_) async {
        await loadBoard();
      },
      onDraggableCanceled: (_, __) async {
        await unlockTask(task);
      },
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 280,
          child: taskCard,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: taskCard,
      ),
      child: taskCard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appColors[0],
        foregroundColor: Colors.white,
        title: Text(
          widget.project['title'],
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: showCreateTaskDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nueva actividad'),
              ),
            ),
          ),
          Expanded(
            child: isMobile
                ? ListView(
              children: columns.map(buildColumn).toList(),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: columns.map(buildColumn).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
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
  List<Map<String, dynamic>> tasks   = [];
  bool isLoading = true;

  final TextEditingController taskTitleController       = TextEditingController();
  final TextEditingController taskDescriptionController = TextEditingController();

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
  }

  @override
  void dispose() {
    if (channel != null) supabase.removeChannel(channel!);
    taskTitleController.dispose();
    taskDescriptionController.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> tasksByColumn(int columnId) =>
      tasks.where((t) => t['column_id'] == columnId).toList();

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
              const SizedBox(height: 4),
              _dialogField('Título', taskTitleController, Icons.title_rounded),
              const SizedBox(height: 12),
              _dialogField('Descripción', taskDescriptionController, Icons.notes_rounded, maxLines: 3),
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

  // ─── Colores de columna ───────────────────────────────────────────────────
  Color _colBg(String name) =>
      _colColors[name.toLowerCase()] ?? const Color(0xFFEDE7F6);
  Color _colDot(String name) =>
      _colDotColors[name.toLowerCase()] ?? const Color(0xFF6A1B9A);
  Color _colText(String name) =>
      _colTextColors[name.toLowerCase()] ?? const Color(0xFF4A148C);

  // ─── Columna estilo Notion ────────────────────────────────────────────────
  Widget buildColumn(Map<String, dynamic> column) {
    final columnTasks = tasksByColumn(column['id']);
    final bg   = _colBg(column['name']);
    final dot  = _colDot(column['name']);
    final text = _colText(column['name']);
    final isMobile = MediaQuery.of(context).size.width < 750;

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
                  Text(column['name'],
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text)),
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
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              if (columnTasks.isEmpty) emptyState,
              if (columnTasks.isNotEmpty)
                Flexible(
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

    final card = Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
        boxShadow: locked
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
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
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            locked ? Icons.lock_rounded : Icons.drag_indicator_rounded,
            size: 16,
            color: locked ? Colors.grey.shade400 : Colors.grey.shade300,
          ),
        ],
      ),
    );

    if (locked) return card;

    return LongPressDraggable<Map<String, dynamic>>(
      data: task,
      onDragStarted:     () async => await lockTask(task),
      onDragEnd:         (_) async => await loadBoard(),
      onDraggableCanceled: (_, __) async => await unlockTask(task),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 280, child: Opacity(opacity: 0.95, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
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
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project['title'],
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
            Text('Mi rol: ${widget.myRole}',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
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
                  child: Row(
                    children: [
                      // Contador de tareas
                      Text(
                        '${tasks.length} actividades',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const Spacer(),
                      // Botón nueva actividad
                      ElevatedButton.icon(
                        onPressed: showCreateTaskDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white,),
                        label: const Text('Nueva actividad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE5E5E3)),
                // ── Tablero ──────────────────────────────────────────
                Expanded(
                  child: isMobile
                      // Móvil: columnas apiladas con scroll vertical
                      ? ListView(
                          padding: const EdgeInsets.all(8),
                          children: columns.map(buildColumn).toList(),
                        )
                      // Desktop: columnas en fila, cada una con scroll propio
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            // Alto fijo = pantalla - appBar - barraTop - divider
                            height: MediaQuery.of(context).size.height - kToolbarHeight - 57,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: columns.map(buildColumn).toList(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Color getColumnColor(String name) {
    switch (name.toLowerCase()) {
      case 'pendiente':  return Colors.orange;
      case 'en proceso': return Colors.blue;
      case 'terminado':  return Colors.green;
      default:           return Colors.purple;
    }
  }
}
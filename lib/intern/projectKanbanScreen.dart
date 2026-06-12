import 'package:flutter/material.dart';
import 'package:innova/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectKanbanScreen extends StatefulWidget {
  final Map<String,dynamic> project;
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
  late RealtimeChannel channel;

  @override
  void dispose() {
    supabase.removeChannel(channel);
    super.dispose();
  }

  List<Map<String,dynamic>> columns = [];
  List<Map<String,dynamic>> tasks = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    loadBoard();
  }

  Future<void> loadBoard() async {

    final projectId = widget.project['id'];

    final columnsResponse = await supabase
        .from('kanban_columnas')
        .select()
        .eq('proyecto_id', projectId)
        .eq('status', true)
        .order('position');

    final tasksResponse = await supabase
        .from('tareas')
        .select()
        .eq('proyecto_id', projectId)
        .eq('status', true)
        .order('created_at');

    columns = List<Map<String,dynamic>>.from(
      columnsResponse,
    );

    tasks = List<Map<String,dynamic>>.from(
      tasksResponse,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  List<Map<String,dynamic>> tasksByColumn(
      int columnId,
      ) {

    return tasks.where(
          (e) => e['column_id'] == columnId,
    ).toList();
  }

  Color getColumnColor(String name) {

    switch(name.toLowerCase()) {

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

  Widget buildColumn(
      Map<String,dynamic> column,
      ) {

    final columnTasks =
    tasksByColumn(column['id']);

    return Container(
      width: 320,
      margin: const EdgeInsets.all(8),
      child: Card(
        child: Column(
          children: [

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: getColumnColor(
                column['name'],
              ),
              child: Text(
                column['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ...columnTasks.map(
              buildTaskCard,
            ),

          ],
        ),
      ),
    );
  }

  Widget buildTaskCard(
      Map<String,dynamic> task,
      ) {

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(task['title']),
        subtitle: Text(
          task['description'] ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final isMobile =
        MediaQuery.of(context).size.width < 700;

    return Scaffold(

      appBar: AppBar(
        title: Text(
          widget.project['title'],
        ),
      ),

      body: isLoading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )

          : isMobile

          ? ListView(
        children: columns
            .map(buildColumn)
            .toList(),
      )

          : SingleChildScrollView(
        scrollDirection:
        Axis.horizontal,
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: columns
              .map(buildColumn)
              .toList(),
        ),
      ),
    );
  }
}
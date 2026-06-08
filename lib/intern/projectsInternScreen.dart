import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';

class ProjectsInternScreen extends StatefulWidget {
  const ProjectsInternScreen({super.key});

  @override
  State<ProjectsInternScreen> createState() => _ProjectsInternScreenState();
}

class _ProjectsInternScreenState extends State<ProjectsInternScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appColors[0],
        automaticallyImplyLeading: false,
        title: const Text('Proyectos', style: TextStyle(color: Colors.white, fontSize: 15),),
      ),
    );
  }
}
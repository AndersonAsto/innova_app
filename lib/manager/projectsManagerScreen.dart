import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';

class ProjectsManagerScreen extends StatefulWidget {
  const ProjectsManagerScreen({super.key});

  @override
  State<ProjectsManagerScreen> createState() => _ProjectsManagerScreenState();
}

class _ProjectsManagerScreenState extends State<ProjectsManagerScreen> {
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
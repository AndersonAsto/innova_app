import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';

class CollaboratorsInternScreen extends StatefulWidget {
  const CollaboratorsInternScreen({super.key});

  @override
  State<CollaboratorsInternScreen> createState() => _CollaboratorsInternScreenState();
}

class _CollaboratorsInternScreenState extends State<CollaboratorsInternScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appColors[0],
        automaticallyImplyLeading: false,
        title: const Text('Colaboradores', style: TextStyle(color: Colors.white, fontSize: 15),),
      ),
    );
  }
}
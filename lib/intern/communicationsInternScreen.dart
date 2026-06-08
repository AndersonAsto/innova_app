import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';

class CommunicationsInternScreen extends StatefulWidget {
  const CommunicationsInternScreen({super.key});

  @override
  State<CommunicationsInternScreen> createState() => _CommunicationsInternScreenState();
}

class _CommunicationsInternScreenState extends State<CommunicationsInternScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appColors[0],
        automaticallyImplyLeading: false,
        title: const Text('Comunicados', style: TextStyle(color: Colors.white, fontSize: 15),),
      ),
    );
  }
}
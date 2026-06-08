import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';

class CommunicationsManagerScreen extends StatefulWidget {
  const CommunicationsManagerScreen({super.key});

  @override
  State<CommunicationsManagerScreen> createState() => _CommunicationsManagerScreenState();
}

class _CommunicationsManagerScreenState extends State<CommunicationsManagerScreen> {
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
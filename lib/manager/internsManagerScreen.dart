import 'package:flutter/material.dart';
import 'package:innova/environments/environments.dart';

class InternsManagerScreen extends StatefulWidget {
  const InternsManagerScreen({super.key});

  @override
  State<InternsManagerScreen> createState() => _InternsManagerScreenState();
}

class _InternsManagerScreenState extends State<InternsManagerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appColors[0],
        automaticallyImplyLeading: false,
        title: const Text('Practicantes', style: TextStyle(color: Colors.white, fontSize: 15),),
      ),
    );
  }
}
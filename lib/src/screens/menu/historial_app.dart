import 'package:flutter/material.dart';

class HistorialApp extends StatefulWidget {
  const HistorialApp({super.key});

  @override
  State<HistorialApp> createState() => _HistorialAppState();
}

class _HistorialAppState extends State<HistorialApp> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial'),
        backgroundColor: Colors.lightGreenAccent,
      ),
    );
  }
}

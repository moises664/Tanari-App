import 'package:flutter/material.dart';

class AcercaApp extends StatelessWidget {
  const AcercaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Acerca de TANARI'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.black54,
      ),
    );
  }
}

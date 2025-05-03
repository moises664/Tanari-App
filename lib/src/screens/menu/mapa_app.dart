// RECORDAR ANEXARLA LUEGO...

import 'package:flutter/material.dart';

class MapaApp extends StatefulWidget {
  const MapaApp({super.key});

  @override
  State<MapaApp> createState() => _MapaAppState();
}

class _MapaAppState extends State<MapaApp> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa Google'),
        backgroundColor: Colors.lightGreenAccent,
      ),
    );
  }
}

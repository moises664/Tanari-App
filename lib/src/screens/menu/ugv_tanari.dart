import 'package:flutter/material.dart';

class UgvTanari extends StatefulWidget {
  const UgvTanari({super.key});

  @override
  State<UgvTanari> createState() => _UgvTanariState();
}

class _UgvTanariState extends State<UgvTanari> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Control del Carrito",
        ),
        backgroundColor: Colors.lightGreenAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_upward, size: 50),
              onPressed: () => ("adelante"),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, size: 50),
                  onPressed: () => ("izquierda"),
                ),
                SizedBox(width: 35),
                IconButton(
                  icon: Icon(Icons.arrow_forward, size: 50),
                  onPressed: () => ("derecha"),
                ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.arrow_downward, size: 50),
              onPressed: () => ("atras"),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ModoUgv extends StatefulWidget {
  const ModoUgv({super.key});

  @override
  State<ModoUgv> createState() => _ModoUgvState();
}

class _ModoUgvState extends State<ModoUgv> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Control del Carrito",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent.shade700,
      ),
      body: Column(
        children: [
          // Mapa del recorrido.
          Container(
            margin: EdgeInsets.all(20),
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.yellow, borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Mapa del Recorrido'),
            ),
          ),
          //indicadores
          Container(
            margin: EdgeInsets.only(left: 20, right: 20, bottom: 10),
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.blueGrey.shade100,
                borderRadius: BorderRadius.circular(10)),
            child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text('Panel de indicadores'),
                    Row(),
                  ],
                )),
          ),
          // Control
          Container(
            height: 300,
            margin: EdgeInsets.only(left: 20, right: 20, bottom: 10),
            decoration: BoxDecoration(
                color: Colors.blueAccent.shade100,
                borderRadius: BorderRadius.circular(10)),
            child: Center(
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
                      SizedBox(width: 55),
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
          ),
        ],
      ),
    );
  }
}

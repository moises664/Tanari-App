import 'package:flutter/material.dart';

class ModoAcople extends StatefulWidget {
  const ModoAcople({super.key});

  @override
  State<ModoAcople> createState() => _ModoAcopleState();
}

class _ModoAcopleState extends State<ModoAcople> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modo de Acople',
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.lightGreenAccent,
      ),
      body: Column(
        children: [
          Monitoreo_Panel(),
          Container(
            margin: EdgeInsets.only(left: 20, right: 20, bottom: 10),
            height: 270,
            width: double.infinity,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.blueAccent),
            child: Text('Control UGV'),
          )
        ],
      ),
    );
  }

  Container Monitoreo_Panel() {
    return Container(
      margin: EdgeInsets.all(20),
      height: 430,
      width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.lightGreenAccent.shade100),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Monitoreo: ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 25,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          monitoreo_co2(),
          monitoreo_ch4(),
          monitoreo_temperatura(),
          monitoreo_humendad(),
        ],
      ),
    );
  }

  Padding monitoreo_co2() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Text(
            'CO2:    ',
            style: TextStyle(fontSize: 25),
          ),
          Container(
            height: 60,
            width: 240,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.lightGreen),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '--  ppm',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

Padding monitoreo_ch4() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      children: [
        Text(
          'CH4:    ',
          style: TextStyle(fontSize: 25),
        ),
        Container(
          height: 60,
          width: 240,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.lightGreen),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                '--  ppm',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ),
        )
      ],
    ),
  );
}

Padding monitoreo_temperatura() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      children: [
        Text(
          'Temp:  ',
          style: TextStyle(fontSize: 25),
        ),
        Container(
          height: 60,
          width: 240,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.lightGreen),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                '--  ºC',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ),
        )
      ],
    ),
  );
}

Padding monitoreo_humendad() {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Row(
      children: [
        Text(
          'Hume:  ',
          style: TextStyle(fontSize: 25),
        ),
        Container(
          height: 60,
          width: 240,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.lightGreen),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                '--  %',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ),
        )
      ],
    ),
  );
}
